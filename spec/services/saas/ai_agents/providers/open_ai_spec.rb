require 'rails_helper'

RSpec.describe Saas::AiAgents::Providers::OpenAi do
  subject(:provider) { described_class.allocate }

  it 'sends only result as the tool message content on success' do
    expect(provider.send(:tool_message_content, 'success' => true, 'result' => 'Mensagem enviada!', 'debug' => { 'id' => 1 })).to eq('Mensagem enviada!')
  end

  it 'sends an explicit failure payload to the model' do
    content = provider.send(:tool_message_content, 'success' => false, 'http_status' => 404, 'error' => 'Contato não encontrado')

    expect(JSON.parse(content)).to include('success' => false, 'http_status' => 404, 'error' => 'Contato não encontrado')
  end

  it 'blocks a repeated tool call after an uncertain result' do
    calls = []
    handler = lambda do |name, arguments|
      calls << [name, arguments]
      { 'success' => false, 'error' => 'The outcome is uncertain.', 'outcome_uncertain' => true }
    end
    tool_calls = []
    uncertain_tool_calls = []
    call = { 'function' => { 'name' => 'consultarConta', 'arguments' => '{"email":"rhuan@example.com"}' } }

    first = provider.send(:run_tool_call, call, handler, tool_calls, uncertain_tool_calls)
    second = provider.send(:run_tool_call, call, handler, tool_calls, uncertain_tool_calls)

    expect(first).to include('outcome_uncertain' => true)
    expect(second).to include('error' => 'tool_retry_blocked', 'retryable' => false)
    expect(calls).to contain_exactly(['consultarConta', { 'email' => 'rhuan@example.com' }])
  end
end
