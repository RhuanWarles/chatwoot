require 'rails_helper'

RSpec.describe Evolution::Configuration do
  let(:channel) { instance_double(Channel::Api, additional_attributes: { 'evolution_instance_name' => 'legacy-instance' }, webhook_url: 'https://evolution.example.test/chatwoot/webhook/legacy-instance') }
  let(:connection) { instance_double(WhatsappConnection, instance_name: 'managed-instance') }
  let(:inbox) { instance_double(Inbox, api?: true, channel: channel, whatsapp_connection: connection) }

  around do |example|
    with_modified_env EVOLUTION_API_URL: 'https://evolution.example.test', EVOLUTION_API_KEY: 'provider-key' do
      example.run
    end
  end

  it 'prioritizes the managed WhatsappConnection instance over the legacy channel value' do
    configuration = described_class.new(inbox)

    expect(configuration.instance_name).to eq('managed-instance')
    expect(configuration).to be_eligible
  end

  it 'keeps resolving a legacy inbox without a WhatsappConnection' do
    legacy_inbox = instance_double(Inbox, api?: true, channel: channel, whatsapp_connection: nil)

    expect(described_class.new(legacy_inbox).instance_name).to eq('legacy-instance')
    expect(described_class.new(legacy_inbox)).to be_eligible
  end
end
