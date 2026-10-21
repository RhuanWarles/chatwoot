require 'rails_helper'

RSpec.describe Evolution::ChatwootConfiguration do
  let(:inbox) { instance_double(Inbox, api?: true) }
  let(:configuration) do
    instance_double(
      Evolution::Configuration,
      eligible?: true,
      instance_name: 'rwhub',
      base_url: 'https://evolution.example.com',
      api_key: 'secret'
    )
  end
  let(:response) do
    instance_double(
      HTTParty::Response,
      success?: true,
      parsed_response: {
        'enabled' => true,
        'accountId' => '48',
        'token' => 'chatwoot-token',
        'url' => 'https://chatwoot.example.com',
        'signMsg' => true,
        'signDelimiter' => "\n",
        'nameInbox' => 'rwhub',
        'reopenConversation' => true,
        'conversationPending' => false,
        'daysLimitImportMessages' => 30,
        'webhook_url' => 'https://evolution.example.com/chatwoot/webhook/rwhub'
      }
    )
  end

  before do
    allow(Evolution::Configuration).to receive(:new).with(inbox).and_return(configuration)
    allow(HTTParty).to receive(:get).and_return(response)
    allow(HTTParty).to receive(:post).and_return(response)
    allow(Rails.logger).to receive(:warn)
  end

  it 'returns only the instance and signing state when reading configuration' do
    result = described_class.new(inbox).show

    expect(result).to eq(instance_name: 'rwhub', configured: true, sign_msg: true)
    expect(HTTParty).to have_received(:get).with(
      'https://evolution.example.com/chatwoot/find/rwhub',
      hash_including(headers: hash_including('apikey' => 'secret'))
    )
  end

  it 'preserves the Evolution configuration and changes only signMsg' do
    described_class.new(inbox).update_sign_msg(false)

    expect(HTTParty).to have_received(:post).with(
      'https://evolution.example.com/chatwoot/set/rwhub',
      hash_including(
        body: include('"accountId":"48"', '"signMsg":false', '"signDelimiter":"\\n"', '"daysLimitImportMessages":30')
      )
    )
  end

  it 'preserves fields introduced by newer Evolution versions' do
    response.parsed_response['futureOption'] = { 'enabled' => true }

    described_class.new(inbox).update_sign_msg(false)

    expect(HTTParty).to have_received(:post).with(
      'https://evolution.example.com/chatwoot/set/rwhub',
      hash_including(body: include('"futureOption":{"enabled":true}'))
    )
  end

  it 'treats an unconfigured instance as a valid initial configuration' do
    response.parsed_response.replace('enabled' => false, 'signMsg' => false, 'accountId' => '', 'token' => '')

    expect(described_class.new(inbox).show).to eq(instance_name: 'rwhub', configured: false, sign_msg: false)
  end

  it 'preserves authentication failures from Evolution' do
    allow(HTTParty).to receive(:get).and_return(
      instance_double(HTTParty::Response, success?: false, code: 401, parsed_response: { 'message' => 'Invalid api key' })
    )

    expect { described_class.new(inbox).show }.to raise_error(CustomExceptions::Evolution) { |error|
      expect(error.code).to eq('permission_denied')
      expect(error.http_status).to eq(422)
    }
    expect(Rails.logger).to have_received(:warn).with(include('status=401', 'Invalid api key'))
  end

  it 'classifies provider validation failures separately' do
    allow(HTTParty).to receive(:get).and_return(
      instance_double(
        HTTParty::Response,
        success?: false,
        code: 400,
        parsed_response: { 'response' => { 'message' => [['daysLimitImportMessages is not a number']] } }
      )
    )

    expect { described_class.new(inbox).show }.to raise_error(CustomExceptions::Evolution) { |error|
      expect(error.code).to eq('validation_error')
      expect(error.http_status).to eq(422)
      expect(error.uncertain).to be(false)
    }
    expect(Rails.logger).to have_received(:warn).with(include('status=400', 'daysLimitImportMessages is not a number'))
  end

  it 'preserves provider failures from Evolution' do
    allow(HTTParty).to receive(:get).and_return(
      instance_double(HTTParty::Response, success?: false, code: 503, parsed_response: { 'message' => 'database unavailable' })
    )

    expect { described_class.new(inbox).show }.to raise_error(CustomExceptions::Evolution) { |error|
      expect(error.code).to eq('provider_error')
      expect(error.http_status).to eq(502)
      expect(error.uncertain).to be(true)
    }
    expect(Rails.logger).to have_received(:warn).with(include('status=503', 'database unavailable'))
  end

  it 'classifies timeouts separately from an unreachable provider' do
    allow(HTTParty).to receive(:get).and_raise(Net::ReadTimeout)

    expect { described_class.new(inbox).show }.to raise_error(CustomExceptions::Evolution) { |error|
      expect(error.code).to eq('timeout')
      expect(error.http_status).to eq(504)
    }
  end

  it 'rejects a successful non-object payload' do
    allow(HTTParty).to receive(:get).and_return(
      instance_double(HTTParty::Response, success?: true, parsed_response: ['unexpected'])
    )

    expect { described_class.new(inbox).show }.to raise_error(CustomExceptions::Evolution) { |error|
      expect(error.code).to eq('invalid_payload')
    }
  end
end
