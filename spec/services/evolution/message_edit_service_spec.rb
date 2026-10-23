require 'rails_helper'

RSpec.describe Evolution::MessageEditService do
  subject(:service) { described_class.new(message: message, content: 'Edited message') }

  let(:account) { create(:account) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
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

  before do
    allow(Evolution::GroupClient).to receive(:new).with(inbox).and_return(client)
    allow(client).to receive(:update_message)
  end

  it 'sends the original WhatsApp key and edited text to Evolution' do
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
