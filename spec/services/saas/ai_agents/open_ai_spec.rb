require 'rails_helper'

RSpec.describe Saas::AiAgents::Providers::OpenAi do
  let(:account) { create(:account) }
  let(:settings) { instance_double(Saas::AiSetting, text_mode: 'byok', text_provider: 'openai', text_api_key: 'secret') }
  let(:client) { instance_double(OpenAI::Client) }
  let(:parameters) { { model: 'test-model', messages: [{ role: 'user', content: 'Hello' }], temperature: 0.2 } }

  before do
    allow(account).to receive(:saas_ai_setting).and_return(settings)
    allow(OpenAI::Client).to receive(:new).and_return(client)
  end

  it 'returns text and whitelisted usage without exposing credentials' do
    allow(client).to receive(:chat).and_return('choices' => [{ 'message' => { 'content' => 'Hello!' } }],
                                              'usage' => { 'total_tokens' => 12, 'secret' => 'ignored' })
    expect(described_class.new(account).generate(**parameters)).to eq(content: 'Hello!', usage: { 'total_tokens' => 12 })
  end

  it 'rejects empty responses' do
    allow(client).to receive(:chat).and_return('choices' => [{ 'message' => { 'content' => '  ' } }])
    expect { described_class.new(account).generate(**parameters) }.to raise_error(CustomExceptions::AiAgentError, 'empty_response')
  end

  it 'sanitizes timeouts and retries them through the transient error type' do
    allow(client).to receive(:chat).and_raise(Faraday::TimeoutError, 'secret request body')
    expect { described_class.new(account).generate(**parameters) }
      .to raise_error(CustomExceptions::AiAgentError::Transient, 'provider_timeout_or_connection_error') { |error| expect(error.cause).to be_nil }
  end

  it 'rejects missing account credentials' do
    allow(account).to receive(:saas_ai_setting).and_return(nil)
    expect { described_class.new(account) }.to raise_error(CustomExceptions::AiAgentError, 'account_openai_key_not_configured')
  end

  [429, 503].each do |status|
    it "classifies HTTP #{status} as transient without retaining the response body" do
      allow(client).to receive(:chat).and_raise(Faraday::ClientError.new('secret', { status: status, body: 'secret' }))
      expect { described_class.new(account).generate(**parameters) }
        .to raise_error(CustomExceptions::AiAgentError::Transient, "provider_http_#{status}")
    end
  end

  it 'does not retry authentication errors' do
    allow(client).to receive(:chat).and_raise(Faraday::ClientError.new('secret', { status: 401, body: 'secret' }))
    expect { described_class.new(account).generate(**parameters) }.to raise_error(CustomExceptions::AiAgentError, 'provider_http_401')
  end
end
