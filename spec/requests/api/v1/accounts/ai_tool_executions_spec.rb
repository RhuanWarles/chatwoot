require 'rails_helper'

RSpec.describe 'AI tool executions API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:tool) do
    account.saas_ai_tools.create!(name: 'Send link', description: 'Sends a link', configuration: {
                                    'method' => 'POST', 'url' => 'https://example.com', 'timeout_seconds' => 10,
                                    'parameters' => [{ 'name' => 'phone', 'type' => 'string', 'sensitive' => true }]
                                  })
  end
  let(:agent) do
    account.saas_ai_agents.create!(name: 'Sales', system_prompt: 'Help', provider: 'openai', model: 'test-model')
  end

  it 'lists only account executions and redacts sensitive arguments in details' do
    execution = account.saas_ai_tool_executions.create!(ai_agent: agent, ai_tool: tool, request_id: SecureRandom.uuid,
                                                        arguments: { 'phone' => '+5511999999999' }, status: 'completed',
                                                        response_status: 200, duration_ms: 42)

    get "/api/v1/accounts/#{account.id}/ai_tool_executions", params: { source: 'conversation' }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['executions']).to be_empty

    get "/api/v1/accounts/#{account.id}/ai_tool_executions/#{execution.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('execution', 'arguments', 'phone')).to eq('***REDACTED***')
  end
end
