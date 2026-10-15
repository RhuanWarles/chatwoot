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
end
