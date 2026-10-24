require 'rails_helper'

RSpec.describe Evolution::MessageEditService do
  subject(:service) { described_class.new(message: message, content: 'Edited message') }

  let(:account) { create(:account) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox).tap(&:reload) }
  let(:key) do
    {
      'id' => 'message-id',
      'remoteJid' => '5511999999999@s.whatsapp.net',
      'fromMe' => true
    }
  end
  let(:message) do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :outgoing,
      content: 'Original message',
      source_id: 'WAID:message-id',
      content_attributes: { 'whatsapp_message_key' => key }
    )
  end
  let(:client) { instance_double(Evolution::GroupClient) }
  let(:chatwoot_configuration) { instance_double(Evolution::ChatwootConfiguration) }

  before do
    allow(Evolution::GroupClient).to receive(:new).with(inbox).and_return(client)
    allow(client).to receive(:update_message)
    allow(Evolution::ChatwootConfiguration).to receive(:new).with(inbox).and_return(chatwoot_configuration)
    allow(chatwoot_configuration).to receive(:show).and_return(sign_msg: false, sign_delimiter: "\n")
  end

  it 'does not add an agent signature when signMsg is disabled' do
    expect(client).to receive(:update_message).with(number: key['remoteJid'], key: key, text: 'Edited message')

    service.perform
  end

  it 'reapplies the agent signature when signMsg is enabled' do
    allow(chatwoot_configuration).to receive(:show).and_return(sign_msg: true, sign_delimiter: '\\n')

    expect(client).to receive(:update_message).with(
      number: key['remoteJid'], key: key, text: "*#{message.sender.available_name}:*\nEdited message"
    )

    service.perform
    expect(message.reload.content).to eq('Original message')
  end

  it 'does not duplicate an existing agent signature' do
    signed_content = "*#{message.sender.available_name}:*\nEdited message"
    service_with_signed_content = described_class.new(message: message, content: signed_content)
    allow(chatwoot_configuration).to receive(:show).and_return(sign_msg: true, sign_delimiter: "\n")

    expect(client).to receive(:update_message).with(number: key['remoteJid'], key: key, text: signed_content)

    service_with_signed_content.perform
  end

  it 'uses the stored WhatsApp key when the Chatwoot source id is unavailable' do
    message.update!(source_id: nil)

    expect(client).to receive(:update_message).with(number: key['remoteJid'], key: key, text: 'Edited message')

    service.perform
  end

  it 'does not allow incoming messages to be edited' do
    message.update!(message_type: :incoming)

    expect { service.perform }.to raise_error(CustomExceptions::Evolution)
    expect(client).not_to have_received(:update_message)
  end

  it 'does not call Evolution when the edit window has expired' do
    message.update!(created_at: 16.minutes.ago)

    expect { service.perform }.to raise_error(CustomExceptions::Evolution)
    expect(client).not_to have_received(:update_message)
  end
end
