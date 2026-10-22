require 'rails_helper'

RSpec.describe Evolution::MessageReactionsService do
  subject(:service) { described_class.new(message) }

  let(:account) { create(:account) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox).reload }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, source_id: 'WAID:target') }
  let(:event) { { 'participant' => '123@lid', 'from_me' => false, 'emoji' => '👍', 'timestamp_ms' => 1000, 'event_id' => 'event-1' } }
  let(:participants) do
    instance_double(Evolution::GroupParticipantsService,
                    perform: [{ lid: '123@lid', jid: '5511999999999@s.whatsapp.net', display_name: 'Saved contact' }])
  end
  let(:client) { instance_double(Evolution::GroupClient) }
  let(:user) { create(:user, account: account) }

  before do
    allow(Evolution::GroupParticipantsService).to receive(:new).with(conversation).and_return(participants)
    allow(Evolution::GroupClient).to receive(:new).and_return(client)
    allow(Evolution::GroupJidResolver).to receive(:call).with(conversation).and_return('120363000000001@g.us')
    allow(client).to receive(:get).with('chatwoot/find').and_return('accountId' => account.id.to_s, 'url' => 'https://chatwoot.test')
  end

  around do |example|
    with_modified_env FRONTEND_URL: 'https://chatwoot.test' do
      example.run
    end
  end

  it 'attaches the reaction to the original message without creating messages, usage or AI work' do
    message
    usage_count = Saas::UsageRecord.count
    expect(Saas::AiAgents::RespondJob).not_to receive(:perform_later)
    expect(Rails.configuration.dispatcher).to receive(:dispatch).with('message.reaction_updated', anything, hash_including(message: message))
    expect { service.receive!(event) }.not_to change(Message, :count)
    expect(Saas::UsageRecord.count).to eq(usage_count)
    record = message.reload.content_attributes.fetch('whatsapp_reactions').sole
    expect(record).to include('emoji' => '👍', 'participant_key' => '5511999999999@s.whatsapp.net', 'display_name' => 'Saved contact')
  end

  it 'replaces the previous emoji and recognizes both LID and phone JID as the same participant' do
    service.receive!(event)
    service.receive!(event.merge('participant' => '5511999999999@s.whatsapp.net', 'emoji' => '❤️', 'event_id' => 'event-2', 'timestamp_ms' => 2000))
    expect(message.reload.content_attributes['whatsapp_reactions'].sole['emoji']).to eq('❤️')
  end

  it 'persists removal tombstones and ignores older events' do
    service.receive!(event)
    service.receive!(event.merge('emoji' => '', 'event_id' => 'remove', 'timestamp_ms' => 2000))
    service.receive!(event.merge('event_id' => 'old', 'timestamp_ms' => 1500))
    expect(message.reload.content_attributes['whatsapp_reactions'].sole['emoji']).to eq('')
  end

  it 'does not broadcast duplicate events' do
    service.receive!(event)
    expect(Rails.configuration.dispatcher).not_to receive(:dispatch)
    service.receive!(event)
    expect(message.reload.content_attributes['whatsapp_reactions'].length).to eq(1)
  end

  it 'uses safe unresolved LID names without deriving a phone number' do
    allow(participants).to receive(:perform).and_return([])
    service.receive!(event)
    expect(message.reload.content_attributes['whatsapp_reactions'].sole).to include('participant_key' => '123@lid',
                                                                                    'display_name' => 'WhatsApp participant')
  end

  it 'sends the actual target key to Evolution and records the internal user' do
    key = { 'id' => 'target', 'remoteJid' => '120363000000001@g.us', 'fromMe' => false, 'participant' => '123@lid' }
    message.update!(content_attributes: { 'whatsapp_message_key' => key })
    expect(client).to receive(:post).with('message/sendReaction', { key: key, reaction: '✅' }).and_return(
      'key' => { 'id' => 'sent' }, 'message' => { 'reactionMessage' => { 'senderTimestampMs' => '2000' } }
    )
    service.send!('✅', user)
    expect(message.reload.content_attributes['whatsapp_reactions'].sole).to include('from_me' => true, 'user_id' => user.id, 'emoji' => '✅')
  end

  it 'sends a reaction for an individual WhatsApp message' do
    key = { 'id' => 'target', 'remoteJid' => '5511999999999@s.whatsapp.net', 'fromMe' => false }
    message.update!(content_attributes: { 'whatsapp_message_key' => key })
    expect(client).to receive(:post).with('message/sendReaction', { key: key, reaction: '✅' }).and_return(
      'key' => { 'id' => 'sent' }, 'message' => { 'reactionMessage' => { 'senderTimestampMs' => '2000' } }
    )

    service.send!('✅', user)

    expect(message.reload.content_attributes['whatsapp_reactions'].sole).to include('from_me' => true, 'user_id' => user.id, 'emoji' => '✅')
  end

  it 'keeps the original state when the provider fails' do
    key = { 'id' => 'target', 'remoteJid' => '120363000000001@g.us', 'fromMe' => true }
    message.update!(content_attributes: { 'whatsapp_message_key' => key })
    allow(client).to receive(:post).and_raise(CustomExceptions::Evolution, :unavailable)
    expect { service.send!('✅', user) }.to raise_error(CustomExceptions::Evolution)
    expect(message.reload.content_attributes).not_to have_key('whatsapp_reactions')
  end

  it 'does not allow removal of a reaction attributed to another operator' do
    message.update!(content_attributes: { 'whatsapp_reactions' => [{ 'participant_key' => 'self', 'from_me' => true, 'user_id' => user.id + 1,
                                                                     'emoji' => '👍' }] })
    expect(client).not_to receive(:post)
    expect { service.send!('', user) }.to raise_error(CustomExceptions::Evolution) { |error| expect(error.code).to eq('permission_denied') }
  end

  it 'does not change conversation activity or unread message state' do
    message
    before = conversation.reload.attributes.slice('last_activity_at', 'waiting_since', 'additional_attributes')
    service.receive!(event)
    expect(conversation.reload.attributes.slice('last_activity_at', 'waiting_since', 'additional_attributes')).to eq(before)
  end

  it 'does not attribute a later phone reaction to the previous internal operator' do
    previous = { 'participant_key' => 'self', 'from_me' => true, 'user_id' => user.id,
                 'display_name' => user.name, 'emoji' => '👍', 'timestamp_ms' => 1000, 'event_id' => 'sent' }
    message.update!(content_attributes: { 'whatsapp_reactions' => [previous] })
    service.receive!(event.merge('from_me' => true, 'emoji' => '❤️', 'event_id' => 'phone', 'timestamp_ms' => 2000))
    expect(message.reload.content_attributes['whatsapp_reactions'].sole['user_id']).to be_nil
  end

  it 'rejects an inbox pointing at an Evolution integration belonging to another account' do
    allow(client).to receive(:get).with('chatwoot/find').and_return('accountId' => (account.id + 1).to_s, 'url' => 'https://chatwoot.test')
    expect(client).not_to receive(:post)
    expect { service.send!('👍', user) }.to raise_error(CustomExceptions::Evolution) { |error| expect(error.code).to eq('permission_denied') }
  end
end
