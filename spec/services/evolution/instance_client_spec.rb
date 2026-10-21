require 'rails_helper'

RSpec.describe Evolution::InstanceClient do
  let(:connection) { instance_double(WhatsappConnection, instance_name: 'account-1-instance', account_id: 1) }
  let(:client) { described_class.new(connection) }
  let(:response) { instance_double(HTTParty::Response, success?: true, parsed_response: { 'instance' => { 'state' => 'close' } }) }

  before do
    allow(Rails.logger).to receive(:warn)
  end

  around do |example|
    with_modified_env EVOLUTION_API_URL: 'https://evolution.example.test', EVOLUTION_API_KEY: 'provider-key' do
      example.run
    end
  end

  it 'uses separate bounded open and read timeouts' do
    allow(HTTParty).to receive(:get).and_return(response)

    expect(client.state).to eq('close')
    expect(HTTParty).to have_received(:get).with(
      'https://evolution.example.test/instance/connectionState/account-1-instance',
      hash_including(open_timeout: 5, read_timeout: 10)
    )
  end

  it 'converts an unexpected successful payload into a controlled provider error' do
    allow(HTTParty).to receive(:get).and_return(
      instance_double(HTTParty::Response, success?: true, parsed_response: { 'unexpected' => true })
    )

    expect { client.state }.to raise_error(CustomExceptions::WhatsappConnection) { |error|
      expect(error.code).to eq('unavailable')
      expect(error.http_status).to eq(502)
    }
  end

  it 'classifies and logs provider validation failures without exposing secrets' do
    allow(HTTParty).to receive(:get).and_return(
      instance_double(
        HTTParty::Response,
        success?: false,
        code: 400,
        parsed_response: { 'message' => 'invalid', 'token' => 'secret-token' }
      )
    )

    expect { client.state }.to raise_error(CustomExceptions::WhatsappConnection) { |error|
      expect(error.code).to eq('validation_error')
      expect(error.http_status).to eq(422)
    }
    expect(Rails.logger).to have_received(:warn).with(
      include('endpoint=instance/connectionState/account-1-instance', 'status=400', '[REDACTED]')
    )
  end
end
