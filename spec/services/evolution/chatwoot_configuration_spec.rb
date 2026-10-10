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
    instance_double(HTTParty::Response, success?: true, parsed_response: {
      'enabled' => true,
      'accountId' => '48',
      'token' => 'chatwoot-token',
      'url' => 'https://chatwoot.example.com',
      'signMsg' => true,
      'signDelimiter' => "\n",
      'nameInbox' => 'rwhub',
      'reopenConversation' => true,
      'conversationPending' => false,
      'webhook_url' => 'https://evolution.example.com/chatwoot/webhook/rwhub'
    })
  end

  before do
    allow(Evolution::Configuration).to receive(:new).with(inbox).and_return(configuration)
    allow(HTTParty).to receive(:get).and_return(response)
    allow(HTTParty).to receive(:post).and_return(response)
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
        body: include('"accountId":"48"', '"signMsg":false', '"signDelimiter":null')
      )
    )
  end
end
