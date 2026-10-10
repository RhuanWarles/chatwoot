require 'rails_helper'

RSpec.describe Saas::AiAgents::Providers::Platform do
  it 'uses the shared text service and returns provider output' do
    allow(Saas::TextService).to receive(:generate_messages).and_return(
      content: 'Resposta', usage: { 'total_tokens' => 12 }
    )

    result = described_class.new.generate(
      model: 'ignored-by-platform', messages: [{ role: 'system', content: 'Ajude' }], temperature: 0.4
    )

    expect(result).to eq(content: 'Resposta', usage: { 'total_tokens' => 12 })
    expect(Saas::TextService).to have_received(:generate_messages).with(
      messages: [{ role: 'system', content: 'Ajude' }], temperature: 0.4
    )
  end

  it 'sanitizes provider failures as transient errors' do
    allow(Saas::TextService).to receive(:generate_messages).and_raise(Faraday::TimeoutError, 'secret')

    expect do
      described_class.new.generate(model: 'model', messages: [], temperature: 0.2)
    end.to raise_error(CustomExceptions::AiAgentError::Transient, 'provider_timeout_or_connection_error')
  end
end
