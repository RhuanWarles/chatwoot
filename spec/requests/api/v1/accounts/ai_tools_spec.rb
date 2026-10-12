require 'rails_helper'

RSpec.describe 'AI Tools API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_tools" }
  let(:configuration) { { method: 'GET', url: 'https://httpbin.org/get', timeout_seconds: 10, parameters: [], headers: {} } }

  it 'creates a tool without a client supplied slug or secret headers' do
    post url, params: { ai_tool: { name: 'SendLink', description: 'Sends a link', configuration: configuration } }, headers: headers, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['slug']).to eq('send_link')
    expect(account.saas_ai_tools.find_by(slug: 'send_link')).to be_present
  end

  it 'returns validation errors instead of 500 for invalid configuration' do
    post url, params: { ai_tool: { name: 'Invalid', description: 'Invalid',
                                  configuration: configuration.merge(url: 'ftp://example.com') } }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to be_present
  end

  it 'persists public headers and extracts sensitive headers from the configuration' do
    post url, params: { ai_tool: { name: 'SendLink', description: 'Sends a link',
                                  configuration: configuration.merge(method: 'POST', headers: { 'X-Test' => 'value', 'Authorization' => 'Bearer secret' }) } },
         headers: headers, as: :json

    expect(response).to have_http_status(:created)
    tool = account.saas_ai_tools.find_by!(slug: 'send_link')
    expect(tool.configuration['headers']).to eq('X-Test' => 'value')
    expect(tool.secret_header_names).to contain_exactly('Authorization')
  end
end
