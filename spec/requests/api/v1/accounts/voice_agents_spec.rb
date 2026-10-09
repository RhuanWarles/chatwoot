require 'rails_helper'

RSpec.describe 'Voice Agents API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:headers) { admin.create_new_auth_token }
  let(:url) { "/api/v1/accounts/#{account.id}/voice_agents" }
  let(:attributes) do
    { name: 'Fernanda', description: 'Commercial calls', provider: 'vapi', assistant_id: 'assistant-123',
      phone_number_id: 'phone-123', active: false, inbound_enabled: true, outbound_enabled: false, max_call_duration: 120 }
  end
  let(:agent) { account.saas_voice_agents.create!(attributes) }

  it 'creates, edits, activates and deactivates configuration without creating calls' do
    expect do
      post url, params: { voice_agent: attributes }, headers: headers, as: :json
    end.not_to change(Saas::VoiceCall, :count)
    expect(response).to have_http_status(:created)
    id = response.parsed_body.fetch('id')
    expect(response.parsed_body).to include('account_id' => account.id, 'assistant_id' => 'assistant-123', 'max_call_duration' => 120)
    expect(response.parsed_body.keys).not_to include('api_key')
    patch "#{url}/#{id}", params: { voice_agent: { active: true, outbound_enabled: true } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('active' => true, 'inbound_enabled' => true, 'outbound_enabled' => true)
    patch "#{url}/#{id}", params: { voice_agent: { active: false, max_call_duration: nil } }, headers: headers, as: :json
    expect(response.parsed_body).to include('active' => false, 'max_call_duration' => nil)
  end

  it 'reads and deletes configuration' do
    get "#{url}/#{agent.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['phone_number_id']).to eq('phone-123')
    delete "#{url}/#{agent.id}", headers: headers
    expect(response).to have_http_status(:no_content)
    expect(account.saas_voice_agents.reload).to be_empty
  end

  it 'keeps text agents and account credentials unchanged' do
    text = account.saas_ai_agents.create!(name: 'Larissa', provider: 'openai', model: 'gpt-4o-mini', system_prompt: 'Keep this prompt')
    text_attributes = text.attributes
    post url, params: { voice_agent: attributes }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(text.reload.attributes).to eq(text_attributes)
    expect(account.reload.saas_ai_setting).to be_nil
  end

  it 'scopes all reads and mutations to the account' do
    agent
    other = create(:account).saas_voice_agents.create!(attributes)
    get url, headers: headers
    expect(response.parsed_body['agents'].pluck('id')).to eq([agent.id])
    expect(response.parsed_body['providers']).to eq(['vapi'])
    expect(response.parsed_body['duration_range']).to eq([10, 3600])
    get "#{url}/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)
    patch "#{url}/#{other.id}", params: { voice_agent: { active: true } }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
    delete "#{url}/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)
    expect(other.reload.active).to be(false)
  end

  it 'rejects invalid types, providers, duration, secrets and tenant assignment with 422' do
    [attributes.merge(name: ' '), attributes.merge(provider: 'unknown'), attributes.merge(active: 'true'),
     attributes.merge(max_call_duration: '120'), attributes.merge(max_call_duration: 1), attributes.merge(max_call_duration: 3601),
     attributes.merge(max_call_duration: 10.5), attributes.merge(account_id: account.id), attributes.merge(api_key: 'secret'),
     attributes.merge(assistant_id: []), attributes.merge(phone_number_id: 'x' * 101)].each do |input|
      post url, params: { voice_agent: input }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
    expect(account.saas_voice_agents).to be_empty
  end

  it 'permits a draft without provider identifiers or duration' do
    post url, params: { voice_agent: { name: 'Draft', provider: 'vapi' } }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      'active' => false, 'inbound_enabled' => false, 'outbound_enabled' => false,
      'assistant_id' => nil, 'phone_number_id' => nil, 'max_call_duration' => nil
    )
  end

  it 'denies all configuration actions to ordinary agents' do
    agent
    get url, headers: user.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
    get "#{url}/#{agent.id}", headers: user.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
    post url, params: { voice_agent: attributes }, headers: user.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    patch "#{url}/#{agent.id}", params: { voice_agent: { active: true } }, headers: user.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    delete "#{url}/#{agent.id}", headers: user.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end
end
