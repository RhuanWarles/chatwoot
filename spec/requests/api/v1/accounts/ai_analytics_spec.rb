require 'rails_helper'

RSpec.describe 'AI analytics API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) do
    account.saas_ai_agents.create!(name: 'Sales', system_prompt: 'Help', provider: 'openai', model: 'test-model')
  end

  before { account.enable_features!('text_ai') }

  it 'aggregates real runtime messages and settled platform usage' do
    Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                    content: 'Hello', content_attributes: { generated_by_ai: true, ai_agent_id: agent.id,
                                                             ai_response_batch_id: 'batch-1', ai_token_usage: { total_tokens: 10 } })
    wallet = account.saas_wallets.create!(resource: 'text_credits', balance_units: 20)
    wallet.usage_records.create!(account: account, conversation: conversation, reference: 'runtime-1', kind: 'consumption',
                                 status: 'settled', units: 1, reserved_units: 1, source: 'runtime',
                                 metadata: { 'ai_agent_id' => agent.id.to_s, 'conversation_id' => conversation.id })

    get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d' }, headers: headers

    expect(response).to have_http_status(:ok)
    data = response.parsed_body
    expect(data.dig('summary', 'conversations')).to eq(1)
    expect(data.dig('summary', 'turns')).to eq(1)
    expect(data.dig('summary', 'messages')).to eq(1)
    expect(data.dig('billing', 'credits_consumed')).to eq(1)
    expect(data.dig('billing', 'credits_available')).to eq(20)
    expect(data.dig('billing', 'average_credits_per_conversation')).to eq(1.0)
    expect(data['timeseries'].sum { |day| day['turns'] }).to eq(1)
    expect(data['timeseries'].sum { |day| day['messages'] }).to eq(1)
  end

  it 'counts split messages once per turn and exposes knowledge utilization' do
    2.times do
      Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                      content: 'Part', content_attributes: { generated_by_ai: true, ai_agent_id: agent.id,
                                                            ai_response_batch_id: 'split', ai_token_usage: { total_tokens: 10 } })
    end
    wallet = account.saas_wallets.create!(resource: 'text_credits', balance_units: 20)
    wallet.usage_records.create!(account: account, reference: 'retrieval', source: 'knowledge_retrieval',
                                 kind: 'consumption', status: 'completed', units: 0,
                                 metadata: { 'conversation_id' => conversation.id, 'retrieval' => { 'accepted_count' => 1 } })

    get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d' }, headers: headers

    expect(response).to have_http_status(:ok)
    data = response.parsed_body
    expect(data.dig('summary', 'turns')).to eq(1)
    expect(data.dig('summary', 'messages')).to eq(2)
    expect(data.dig('knowledge', 'conversations')).to eq(1)
    expect(data.dig('knowledge', 'utilization_rate')).to eq(100.0)
    expect(data['timeseries'].sum { |day| day['tokens'] }).to eq(10)
  end

  describe 'tokens and estimated cost inputs' do
    def ai_reply(batch, usage, model: 'gpt-4.1')
      Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: 'Reply',
                      content_attributes: { generated_by_ai: true, ai_agent_id: agent.id, ai_response_batch_id: batch,
                                            ai_provider: 'openai', ai_model: model, ai_token_usage: usage })
    end

    it 'reports input and output tokens in platform mode too, counting a split turn once' do
      account.saas_wallets.create!(resource: 'text_credits', balance_units: 20)
      2.times { ai_reply('split', { prompt_tokens: 100, completion_tokens: 10, total_tokens: 110 }) }
      ai_reply('single', { prompt_tokens: 50, completion_tokens: 5, total_tokens: 55 })

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d' }, headers: headers

      billing = response.parsed_body['billing']
      expect(billing['mode']).to eq('platform')
      expect(billing).to include('prompt_tokens' => 150, 'completion_tokens' => 15, 'total_tokens' => 165)
      expect(billing['credits_available']).to eq(20)
    end

    it 'breaks the tokens down by model so each one can be priced' do
      ai_reply('a', { prompt_tokens: 100, completion_tokens: 10, total_tokens: 110 })
      ai_reply('b', { prompt_tokens: 40, completion_tokens: 4, total_tokens: 44 })
      ai_reply('c', { prompt_tokens: 7, completion_tokens: 1, total_tokens: 8 }, model: 'other-model')

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d' }, headers: headers

      models = response.parsed_body.dig('billing', 'models')
      expect(models.map { |item| item['model'] }).to eq(%w[gpt-4.1 other-model])
      expect(models.first).to include('provider' => 'openai', 'responses' => 2, 'prompt_tokens' => 140, 'completion_tokens' => 14)
      expect(models.last).to include('responses' => 1, 'prompt_tokens' => 7, 'completion_tokens' => 1)
    end

    it 'treats a turn without usage as zero tokens' do
      Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: 'No usage',
                      content_attributes: { generated_by_ai: true, ai_agent_id: agent.id })

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d' }, headers: headers

      expect(response.parsed_body['billing']).to include('prompt_tokens' => 0, 'completion_tokens' => 0, 'total_tokens' => 0)
    end
  end

  describe 'knowledge questions without an answer' do
    let(:wallet) { account.saas_wallets.create!(resource: 'text_credits', balance_units: 20) }

    def retrieval(query, accepted)
      wallet.usage_records.create!(account: account, reference: SecureRandom.hex(4), source: 'knowledge_retrieval',
                                   kind: 'consumption', status: 'completed', units: 0,
                                   metadata: { 'conversation_id' => conversation.id,
                                               'retrieval' => { 'query' => query, 'accepted_count' => accepted } })
    end

    before do
      Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: 'Reply',
                      content_attributes: { generated_by_ai: true, ai_agent_id: agent.id })
    end

    it 'lists the most frequent questions that found nothing, ignoring the answered ones' do
      3.times { retrieval('qual o prazo de entrega?', 0) }
      retrieval('tem desconto?', 0)
      retrieval('como pagar?', 2)
      retrieval('', 0)

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d' }, headers: headers

      expect(response.parsed_body.dig('knowledge', 'unanswered')).to eq(
        [{ 'query' => 'qual o prazo de entrega?', 'count' => 3 }, { 'query' => 'tem desconto?', 'count' => 1 }]
      )
    end

    it 'keeps only the five most frequent questions' do
      6.times { |index| (index + 1).times { retrieval("pergunta #{index}", 0) } }

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d' }, headers: headers

      unanswered = response.parsed_body.dig('knowledge', 'unanswered')
      expect(unanswered.length).to eq(5)
      expect(unanswered.first).to eq('query' => 'pergunta 5', 'count' => 6)
    end

    it 'is empty when every question was answered' do
      retrieval('como pagar?', 1)

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d' }, headers: headers

      expect(response.parsed_body.dig('knowledge', 'unanswered')).to eq([])
    end
  end

  describe 'replies from bots that are not AI agents' do
    let(:bot) { create(:agent_bot, account: account) }

    before do
      Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: 'AI',
                      content_attributes: { generated_by_ai: true, ai_agent_id: agent.id })
      Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: 'Bot',
                      sender: bot)
      Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: 'Note',
                      sender: bot, private: true)
    end

    it 'exposes how many public bot replies are not in the AI message count' do
      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d' }, headers: headers

      expect(response.parsed_body['summary']).to include('messages' => 1, 'other_bot_messages' => 1)
    end

    it 'has no number when a single AI agent is chosen, since those replies belong to no agent' do
      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d', ai_agent_id: agent.id }, headers: headers

      expect(response.parsed_body['summary']['other_bot_messages']).to be_nil
    end

    it 'respects the inbox filter' do
      other_inbox = create(:inbox, account: account)

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '30d', inbox_id: other_inbox.id }, headers: headers

      expect(response.parsed_body['summary']).to include('messages' => 0, 'other_bot_messages' => 0)
    end
  end

  it 'uses calendar boundaries for today and this month' do
    %w[today month].each do |period|
      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: period }, headers: headers

      expect(response).to have_http_status(:ok)
      start_at = Time.zone.parse(response.parsed_body.dig('filters', 'start_at'))
      expect(start_at).to eq(period == 'today' ? Time.current.beginning_of_day : Time.current.beginning_of_month)
    end
  end

  it 'does not expose another account data' do
    foreign = create(:account)
    foreign_agent = foreign.saas_ai_agents.create!(name: 'Other', system_prompt: 'Help', provider: 'openai', model: 'test-model')
    foreign_conversation = create(:conversation, account: foreign)
    Message.create!(account: foreign, inbox: foreign_conversation.inbox, conversation: foreign_conversation,
                    message_type: :outgoing, content: 'Secret', content_attributes: { generated_by_ai: true, ai_agent_id: foreign_agent.id })

    get "/api/v1/accounts/#{account.id}/ai_analytics", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('summary', 'messages')).to eq(0)
  end

  describe 'days of the account' do
    # 01:30 UTC of the 12th is 22:30 of the 11th in São Paulo.
    around { |example| travel_to(Time.utc(2026, 11, 12, 1, 30)) { example.run } }

    def late_reply
      Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: 'Late',
                      created_at: Time.utc(2026, 11, 12, 1, 0),
                      content_attributes: { generated_by_ai: true, ai_agent_id: agent.id, ai_response_batch_id: 'late' })
    end

    it 'puts a late-night reply on the day the account lived it, once the account has a reporting time zone' do
      account.update!(reporting_timezone: 'America/Sao_Paulo')
      late_reply

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '7d' }, headers: headers

      data = response.parsed_body
      expect(data.dig('filters', 'timezone')).to eq('America/Sao_Paulo')
      expect(data['timeseries'].find { |day| day['messages'] == 1 }['date']).to eq('2026-11-11')
    end

    it 'keeps using UTC days when the account has no reporting time zone' do
      late_reply

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { period: '7d' }, headers: headers

      expect(response.parsed_body['timeseries'].find { |day| day['messages'] == 1 }['date']).to eq('2026-11-12')
    end

    it 'takes a custom period as whole days of the account' do
      account.update!(reporting_timezone: 'America/Sao_Paulo')
      late_reply

      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { start_date: '2026-11-11', end_date: '2026-11-11' }, headers: headers

      expect(response.parsed_body.dig('summary', 'messages')).to eq(1)
    end

    it 'refuses a custom day that is not a day' do
      get "/api/v1/accounts/#{account.id}/ai_analytics", params: { start_date: 'ontem' }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('invalid_period')
    end
  end
end
