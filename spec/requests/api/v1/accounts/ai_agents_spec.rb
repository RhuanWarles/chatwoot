require 'rails_helper'

RSpec.describe 'AI Agents API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:headers) { admin.create_new_auth_token }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_agents" }
  let(:inbox) { create(:inbox, account: account) }
  let(:attributes) { { name: 'Sales', system_prompt: "Line one\nLine two", provider: 'openai', model: 'test-model' } }
  let(:agent) { account.saas_ai_agents.build.configure!(attributes, selected_inboxes: [inbox]) }

  it 'creates, reads, edits, activates and deletes an agent and its links' do
    post url, params: { ai_agent: attributes.merge(inbox_ids: [inbox.id]) }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body.fetch('id')
    expect(response.parsed_body['inboxes'].pluck('id')).to eq([inbox.id])
    expect(response.parsed_body['respond_to_groups']).to be(false)
    expect(response.parsed_body['context_messages_limit']).to eq(20)
    expect(response.parsed_body['split_response_messages']).to be(true)
    expect(response.parsed_body['audio_enabled']).to be(false)
    expect(response.parsed_body['timezone']).to eq('America/Sao_Paulo')
    expect(response.parsed_body).not_to have_key('max_messages_per_response')
    expect(response.parsed_body.keys).not_to include('api_key')
    patch "#{url}/#{id}", params: { ai_agent: { active: true, description: 'Updated', respond_to_groups: true } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['active']).to be(true)
    expect(response.parsed_body['respond_to_groups']).to be(true)
    get "#{url}/#{id}", headers: headers
    expect(response.parsed_body['system_prompt']).to eq(attributes[:system_prompt])
    delete "#{url}/#{id}", headers: headers
    expect(response).to have_http_status(:no_content)
    expect(Saas::AiAgentInbox.where(ai_agent_id: id)).to be_empty
  end

  it 'persists the audio understanding toggle per agent' do
    post url, params: { ai_agent: attributes.merge(audio_enabled: true) }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body.fetch('id')
    expect(response.parsed_body['audio_enabled']).to be(true)

    patch "#{url}/#{id}", params: { ai_agent: { audio_enabled: false } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['audio_enabled']).to be(false)
    expect(account.saas_ai_agents.find(id).audio_enabled).to be(false)
  end

  it 'persists valid timezones and rejects an invalid update' do
    post url, params: { ai_agent: attributes.merge(timezone: 'America/Manaus') }, headers: headers, as: :json
    id = response.parsed_body.fetch('id')
    expect(response.parsed_body['timezone']).to eq('America/Manaus')

    patch "#{url}/#{id}", params: { ai_agent: { timezone: 'Europe/Lisbon' } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['timezone']).to eq('Europe/Lisbon')

    patch "#{url}/#{id}", params: { ai_agent: { timezone: 'Mars/Olympus' } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to include('error' => 'invalid_settings', 'field' => 'timezone')
    expect(account.saas_ai_agents.find(id).timezone).to eq('Europe/Lisbon')
  end

  it 'scopes lists and direct reads to the current account' do
    other = create(:account).saas_ai_agents.create!(attributes)
    get url, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['agents']).to be_empty
    get "#{url}/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)
    patch "#{url}/#{other.id}", params: { ai_agent: { active: true } }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
    delete "#{url}/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects another account inbox without persisting the agent' do
    post url, params: { ai_agent: attributes.merge(inbox_ids: [create(:inbox).id]) }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.saas_ai_agents.count).to eq(0)
  end

  it 'rejects competing activation and preserves the original links' do
    agent.configure!({ active: true })
    other = account.saas_ai_agents.build.configure!(attributes, selected_inboxes: [inbox])
    patch "#{url}/#{other.id}", params: { ai_agent: { active: true } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('inbox_conflict')
    expect(other.reload.active).to be(false)
  end

  it 'rejects malformed and missing fields with 422' do
    [{ name: ' ' }, attributes.merge(temperature: '0.7'), attributes.merge(active: 'true'), attributes.merge(context_messages_limit: 0),
     attributes.merge(temperature: 2), attributes.merge(respond_to_groups: 'true'), attributes.merge(inbox_ids: [inbox.id.to_s]),
     attributes.merge(inbox_ids: [inbox.id, inbox.id]), attributes.merge(account_id: account.id)].each do |input|
      post url, params: { ai_agent: input }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
    expect(account.saas_ai_agents.count).to eq(0)
  end

  it 'rejects ordinary agents for all configuration actions' do
    agent
    get url, headers: user.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
    post url, params: { ai_agent: attributes }, headers: user.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    patch "#{url}/#{agent.id}", params: { ai_agent: { active: true } }, headers: user.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    delete "#{url}/#{agent.id}", headers: user.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end
end
