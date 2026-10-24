require 'rails_helper'

RSpec.describe Evolution::MessageEditSyncService do
  subject(:service) do
    described_class.new(
      message: message,
      content: 'Edited message',
      instance_name: instance_name,
      whatsapp_message_key: key,
      edited_at: '2026-10-23T19:00:00Z'
    )
  end

  let(:account) { create(:account) }
  let(:api_channel) { create(:channel_api, account: account) }
  let(:inbox) { api_channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox).tap(&:reload) }
  let(:instance_name) { 'account-48-85652885f634bc05' }
  let(:key) do
    {
      'id' => 'message-id',
      'remoteJid' => '281449391493336@lid',
      'remoteJidAlt' => '556294665004@s.whatsapp.net',
      'fromMe' => false
    }
  end
  let(:message) do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :incoming,
      content: 'Original message',
      source_id: 'WAID:message-id',
      content_attributes: {
        'whatsapp_message_key' => key,
        'existing_attribute' => 'preserved'
      }
    )
  end

  before do
    api_channel.update!(additional_attributes: { 'evolution_instance_name' => instance_name })
  end

  it 'syncs an incoming WhatsApp edit without applying manual edit eligibility' do
    message
    sender_id = message.sender_id
    sender_type = message.sender_type

    expect { service.perform }.not_to change(Message, :count)

    expect(message.reload.content).to eq('Edited message')
    expect(message.sender_id).to eq(sender_id)
    expect(message.sender_type).to eq(sender_type)
    expect(message.content_attributes).to include(
      'existing_attribute' => 'preserved',
      'whatsapp_message_edited' => true,
      'whatsapp_message_edit_source' => 'whatsapp_incoming',
      'whatsapp_message_edited_at' => '2026-10-23T19:00:00Z'
    )
    expect(message.content_attributes['whatsapp_message_key']).to include(key)
  end

  it 'dispatches the standard message update event for realtime consumers' do
    message
    expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
      'message.updated',
      an_instance_of(ActiveSupport::TimeWithZone),
      hash_including(message: message)
    )

    service.perform
  end

  it 'syncs an outgoing WhatsApp edit' do
    message.update!(message_type: :outgoing)

    service.perform

    expect(message.reload.content_attributes['whatsapp_message_edit_source']).to eq('whatsapp_outgoing')
  end

  it 'rejects a key that does not identify the stored WhatsApp message' do
    message_key = key.merge('id' => 'different-message-id')
    invalid_service = described_class.new(
      message: message,
      content: 'Edited message',
      instance_name: instance_name,
      whatsapp_message_key: message_key
    )

    expect { invalid_service.perform }.to raise_error(CustomExceptions::Evolution) do |error|
      expect(error.code).to eq('message_edit_sync_invalid')
    end
    expect(message.reload.content).to eq('Original message')
  end

  it 'rejects a key with the same id but a different WhatsApp identity' do
    invalid_service = described_class.new(
      message: message,
      content: 'Edited message',
      instance_name: instance_name,
      whatsapp_message_key: key.merge(
        'remoteJid' => 'other@lid',
        'remoteJidAlt' => 'other@s.whatsapp.net'
      )
    )

    expect { invalid_service.perform }.to raise_error(CustomExceptions::Evolution) do |error|
      expect(error.code).to eq('message_edit_sync_invalid')
    end
    expect(message.reload.content).to eq('Original message')
  end

  it 'rejects a key with a different fromMe value' do
    invalid_service = described_class.new(
      message: message,
      content: 'Edited message',
      instance_name: instance_name,
      whatsapp_message_key: key.merge('fromMe' => true)
    )

    expect { invalid_service.perform }.to raise_error(CustomExceptions::Evolution) do |error|
      expect(error.code).to eq('message_edit_sync_invalid')
    end
    expect(message.reload.content).to eq('Original message')
  end

  it 'is idempotent for a duplicate edit event' do
    service.perform
    updated_at = message.reload.updated_at

    described_class.new(
      message: message,
      content: 'Edited message',
      instance_name: instance_name,
      whatsapp_message_key: key,
      edited_at: '2026-10-23T19:01:00Z'
    ).perform

    expect(message.reload.updated_at).to eq(updated_at)
  end
end
