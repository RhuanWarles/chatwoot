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
end
