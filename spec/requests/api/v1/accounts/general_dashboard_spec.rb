require 'rails_helper'

RSpec.describe 'General dashboard API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:url) { "/api/v1/accounts/#{account.id}/general_dashboard" }
  let(:now) { Time.utc(2026, 11, 12, 15) }

  around { |example| travel_to(now) { example.run } }

  # Rows go straight into the table: the examples are about what the numbers see, not about the callbacks of a message.
  def add_message(conversation:, at:, type: 1, sender: {}, attributes: {})
    # rubocop:disable Rails/SkipsModelValidations
    Message.insert_all([{ account_id: account.id, inbox_id: conversation.inbox_id, conversation_id: conversation.id, message_type: type,
                          private: false, content: 'Hi', status: 0, content_type: 0, sender_type: sender[:type], sender_id: sender[:id],
                          content_attributes: attributes, created_at: at, updated_at: at }])
    # rubocop:enable Rails/SkipsModelValidations
  end

  def ai_reply(conversation, at:)
    add_message(conversation: conversation, at: at, sender: { type: 'Saas::AiAgent', id: 1 }, attributes: { generated_by_ai: true })
  end

  def person_reply(conversation, at:)
    add_message(conversation: conversation, at: at, sender: { type: 'User', id: agent.id })
  end

  def dashboard(params = {})
    get url, params: { period: '7d' }.merge(params), headers: admin.create_new_auth_token
    response.parsed_body
  end

  describe 'access' do
    it 'is for who can see reports, not for an agent' do
      get url, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end

    it 'answers the administrator with the period and the account time zone' do
      account.update!(reporting_timezone: 'America/Sao_Paulo')
      data = dashboard

      expect(response).to have_http_status(:ok)
      expect(data['filters']).to include('timezone' => 'America/Sao_Paulo')
      expect(data['inboxes'].pluck('id')).to include(inbox.id)
    end

    it 'refuses an inbox of another account and a period that is not one' do
      get url, params: { inbox_id: create(:inbox).id }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)

      get url, params: { start_date: 'ontem' }, headers: admin.create_new_auth_token
      expect(response.parsed_body['error']).to eq('invalid_period')
    end
  end

  describe 'attendance' do
    let(:other) { create(:conversation, account: account, inbox: inbox) }

    before do
      add_message(conversation: conversation, at: now - 2.days, type: 0)
      ai_reply(conversation, at: now - 2.days + 1.minute)
      ai_reply(other, at: now - 1.day)
      person_reply(other, at: now - 1.day + 5.minutes)
      person_reply(conversation, at: now - 10.days)
    end

    it 'counts the conversations that had activity in the period, and the ones in the period before' do
      activity = dashboard.dig('attendance', 'activity')

      expect(activity['conversations']).to eq(2)
      expect(activity['previous']).to eq(1)
      expect(activity['per_day'].length).to eq(7)
    end

    it 'splits the replies of each day between the AI and people' do
      replies = dashboard.dig('attendance', 'replies')

      expect(replies).to include('ai' => 2, 'people' => 1)
      expect(replies['ai_share']).to eq(66.67)
    end

    it 'tells how many conversations with a reply were answered only by the AI' do
      handled = dashboard.dig('attendance', 'handled')

      expect(handled).to include('responded' => 2, 'ai_only' => 1, 'ai_only_share' => 50.0)
    end

    it 'lists the people who replied, with their conversations and replies' do
      agents = dashboard.dig('attendance', 'agents')

      expect(agents).to contain_exactly(include('id' => agent.id, 'replies' => 1, 'conversations' => 1))
    end

    it 'only looks at the chosen inbox' do
      other_inbox = create(:inbox, account: account)

      data = dashboard(inbox_id: other_inbox.id)
      expect(data.dig('attendance', 'activity', 'conversations')).to eq(0)
    end
  end

  describe 'waiting customers' do
    it 'lists who wrote and is still waiting, oldest first, and ignores resolved conversations' do
      waiting = create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account, name: 'Padaria'))
      fresh = create(:conversation, account: account, inbox: inbox)
      resolved = create(:conversation, account: account, inbox: inbox, status: :resolved)
      waiting.update_columns(waiting_since: now - 42.minutes) # rubocop:disable Rails/SkipsModelValidations
      fresh.update_columns(waiting_since: now - 3.minutes) # rubocop:disable Rails/SkipsModelValidations
      resolved.update_columns(waiting_since: now - 5.hours) # rubocop:disable Rails/SkipsModelValidations

      data = dashboard.dig('attendance', 'waiting')

      expect(data).to include('total' => 2, 'fresh' => 1, 'middle' => 1, 'late' => 0, 'oldest_minutes' => 42)
      expect(data['list'].first).to include('contact' => 'Padaria', 'minutes' => 42)
    end
  end

  describe 'first response' do
    it 'averages the recorded first responses and compares with the period before' do
      [[now - 1.day, 120], [now - 2.days, 240], [now - 9.days, 600]].each do |at, seconds|
        ReportingEvent.create!(account: account, inbox: inbox, name: 'first_response', value: seconds, created_at: at)
      end

      data = dashboard.dig('attendance', 'first_response')

      expect(data).to include('average' => 180.0, 'median' => 180.0, 'previous_average' => 600.0, 'count' => 2)
    end

    it 'has no average when there is nothing to average, not a zero' do
      data = dashboard.dig('attendance', 'first_response')

      expect(data).to include('average' => nil, 'median' => nil, 'count' => 0)
    end
  end

  describe 'when customers write' do
    it 'puts each new conversation in the weekday and hour of the account, not of UTC' do
      account.update!(reporting_timezone: 'America/Sao_Paulo')
      # Wednesday 11/11 at 22:30 in São Paulo (01:30 UTC of Thursday).
      create(:conversation, account: account, inbox: inbox, created_at: Time.utc(2026, 11, 12, 1, 30))

      heatmap = dashboard.dig('attendance', 'heatmap')

      expect(heatmap[2][22]).to eq(1)
      expect(heatmap.flatten.sum).to eq(1)
    end
  end

  describe 'AI block' do
    it 'comes from the AI analytics for the same period, only when the account has the AI' do
      account.disable_features!('text_ai')
      expect(dashboard['ai']).to be_nil

      account.enable_features!('text_ai')
      data = dashboard['ai']

      expect(data['summary']).to include('conversations' => 0, 'handoffs' => 0)
      expect(data['billing']).to include('models' => [])
    end
  end

  describe 'CRM block' do
    let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
    let(:new_stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
    let(:talk_stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Conversa', position: 1) }

    def deal(stage, value, **attributes)
      account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: create(:contact, account: account), name: 'Lead',
                                value: value, **attributes)
    end

    it 'has no pipeline to show when the account has none' do
      expect(dashboard['crm']).to include('pipelines' => [], 'pipeline_id' => nil)
    end

    it 'counts the open deals of each stage with their value' do
      deal(new_stage, 100)
      deal(new_stage, 50)
      deal(talk_stage, 400)

      funnel = dashboard.dig('crm', 'funnel')

      expect(funnel.map { |stage| [stage['name'], stage['deals'], stage['value']] }).to eq([['Novo', 2, 150.0], ['Conversa', 1, 400.0]])
      expect(dashboard.dig('crm', 'open_value')).to eq(550.0)
    end

    it 'counts the deals won and lost in the period, the win rate and why they were lost' do
      reason = account.crm_lost_reasons.create!(name: 'Preço')
      deal(new_stage, 300).update!(status: 'won')
      deal(new_stage, 80).update!(status: 'lost', lost_reason: reason)
      deal(new_stage, 20).update!(status: 'lost', lost_reason: reason)

      crm = dashboard['crm']

      expect(crm['won']).to eq('deals' => 1, 'value' => 300.0)
      expect(crm['lost']).to eq('deals' => 2, 'value' => 100.0)
      expect(crm['win_rate']).to eq(33.33)
      expect(crm['lost_reasons']).to eq([{ 'id' => reason.id, 'name' => 'Preço', 'deals' => 2 }])
    end
  end

  describe 'blasts block' do
    it 'counts what was sent, delivered and answered by campaign' do
      skip 'campaign recipients are not available here' unless defined?(CampaignRecipient)

      campaign = create(:campaign, account: account, inbox: inbox, campaign_type: :one_off, scheduled_at: now + 1.hour)
      contact = create(:contact, account: account)
      other_contact = create(:contact, account: account)
      [[contact, :delivered], [other_contact, :read]].each do |person, status|
        CampaignRecipient.create!(account: account, campaign: campaign, contact: person, inbox: inbox, status: status, sent_at: now - 1.day,
                                  source_id: SecureRandom.hex(4))
      end
      customer = create(:conversation, account: account, inbox: inbox, contact: contact)
      add_message(conversation: customer, at: now - 20.hours, type: 0)

      blasts = dashboard['blasts']

      expect(blasts).to include('available' => true, 'sent' => 2, 'delivered' => 2, 'replied' => 1)
      expect(blasts['campaigns'].first).to include('title' => campaign.title, 'sent' => 2, 'replied' => 1)
    end
  end
end
