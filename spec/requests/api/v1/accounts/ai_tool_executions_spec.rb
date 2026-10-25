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
  let(:conversation) { create(:conversation, account: account) }
  before { account.enable_features!('text_ai') }

  it 'filters by conversation display ID, orders newest first and paginates' do
    other = create(:conversation, account: account)
    26.times do |index|
      account.saas_ai_tool_executions.create!(ai_agent: agent, ai_tool: tool, conversation: conversation,
                                            request_id: SecureRandom.uuid, status: 'completed', created_at: index.minutes.ago)
    end
    account.saas_ai_tool_executions.create!(ai_agent: agent, ai_tool: tool, conversation: other,
                                          request_id: SecureRandom.uuid, status: 'failed', error_code: 'tool_not_available')
    get "/api/v1/accounts/#{account.id}/ai_tool_executions", params: { conversation_id: conversation.display_id }, headers: headers
    expect(response).to have_http_status(:ok)
    data = response.parsed_body
    expect(data.dig('meta', 'total_count')).to eq(26)
    expect(data['executions'].size).to eq(25)
    expect(data['executions'].pluck('conversation_id').uniq).to eq([conversation.id])
    times = data['executions'].pluck('created_at')
    expect(times).to eq(times.sort.reverse)
    get "/api/v1/accounts/#{account.id}/ai_tool_executions", params: { conversation_id: conversation.display_id, page: 2 }, headers: headers
    expect(response.parsed_body['executions'].size).to eq(1)
  end

  it 'returns conversation failures and recursively redacts sensitive details' do
    execution = account.saas_ai_tool_executions.create!(ai_agent: agent, ai_tool: tool, conversation: conversation,
                                                      request_id: SecureRandom.uuid, status: 'failed', error_code: 'tool_not_available',
                                                      arguments: { 'items' => [{ 'phone' => 'secret', 'Authorization' => 'Bearer secret', 'name' => 'Public' }] })
    get "/api/v1/accounts/#{account.id}/ai_tool_executions/#{execution.id}", params: { conversation_id: conversation.display_id }, headers: headers
    expect(response).to have_http_status(:ok)
    data = response.parsed_body['execution']
    expect(data['error_code']).to eq('tool_not_available')
    expect(data['arguments']['items'].first).to eq('phone' => '***REDACTED***', 'Authorization' => '***REDACTED***', 'name' => 'Public')
    expect(data).not_to have_key('configuration')
    expect(data).not_to have_key('secret_headers')
  end

  it 'returns the sanitized tool response in execution details' do
    execution = account.saas_ai_tool_executions.create!(ai_agent: agent, ai_tool: tool, conversation: conversation,
                                                      request_id: SecureRandom.uuid, status: 'completed', response_status: 200,
                                                      response_body: '{"saldo":"27h 17m","token":"secret"}')

    get "/api/v1/accounts/#{account.id}/ai_tool_executions/#{execution.id}", params: { conversation_id: conversation.display_id }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('execution', 'response')).to eq('{"saldo":"27h 17m","token":"[REDACTED]"}')
  end

  it 'rejects conversations in another account and mismatched detail IDs' do
    foreign = create(:conversation)
    foreign.update!(display_id: conversation.display_id + 100_000)
    get "/api/v1/accounts/#{account.id}/ai_tool_executions", params: { conversation_id: foreign.display_id }, headers: headers
    expect(response).to have_http_status(:not_found)
    execution = account.saas_ai_tool_executions.create!(ai_agent: agent, ai_tool: tool, request_id: SecureRandom.uuid, status: 'completed')
    get "/api/v1/accounts/#{account.id}/ai_tool_executions/#{execution.id}", params: { conversation_id: conversation.display_id }, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'allows inbox agents to read scoped logs but forbids global logs' do
    member = create(:user, account: account, role: :agent)
    create(:inbox_member, inbox: conversation.inbox, user: member)
    get "/api/v1/accounts/#{account.id}/ai_tool_executions", params: { conversation_id: conversation.display_id }, headers: member.create_new_auth_token
    expect(response).to have_http_status(:ok)
    get "/api/v1/accounts/#{account.id}/ai_tool_executions", headers: member.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
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
