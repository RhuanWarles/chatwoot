require 'rails_helper'

RSpec.describe Saas::AiAgents::GroupResponseBlacklist do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:agent) { account.saas_ai_agents.build(group_response_blacklist: ['5562999991111']) }
  let(:message) do
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation, sender: conversation.contact,
                     content_attributes: { participant: '5562999991111@s.whatsapp.net' })
  end

  before { conversation.contact_inbox.update!(source_id: '120363123456789@g.us') }

  it 'normalizes formatted phones without dropping the country code' do
    ['+55 (62) 99999-1111', '5562999991111', '55 62 99999-1111'].each do |number|
      expect(described_class.phone(number)).to eq('5562999991111')
    end
    expect(described_class.phone('+290 1234')).to eq('2901234')
  end

  it 'accepts an empty array but rejects malformed lists and entries' do
    expect(described_class.valid?([])).to be(true)
    [nil, {}, '', [''], [nil], [123_456_789], [{}], ['abc5562999991111'], ['123'], ['+0000000']].each do |value|
      expect(described_class.valid?(value)).to be(false)
    end
  end

  it 'blocks the actual group author without altering the stored message' do
    expect(described_class.blocked?(agent, message)).to be(true)
    expect(message.reload.content).to be_present
    expect(conversation.messages).to include(message)
  end

  it 'does not block private conversations or other participants' do
    message.update!(content_attributes: { participant: '5562988882222@s.whatsapp.net' })
    expect(described_class.blocked?(agent, message)).to be(false)
    conversation.contact_inbox.update!(source_id: '5562999991111@s.whatsapp.net')
    message.update!(content_attributes: { participant: '5562999991111@s.whatsapp.net' })
    expect(described_class.blocked?(agent, message)).to be(false)
  end

  it 'uses participantAlt in the stored WhatsApp key without looking up LID when a phone is available' do
    message.update!(content_attributes: { whatsapp_message_key: {
                      remoteJid: '120363123456789@g.us', participant: '247613823709228@lid', participantAlt: '5562999991111@s.whatsapp.net'
                    } })
    expect(Evolution::GroupParticipantsService).not_to receive(:new)
    expect(described_class.blocked?(agent, message)).to be(true)
  end

  it 'does not treat LID digits as a phone and resolves participantAlt from nested message metadata' do
    message.update!(content_attributes: { data: { key: {
                      remoteJid: '120363123456789@g.us', participant: '247613823709228@lid',
                      participantAlt: '5562999991111@s.whatsapp.net'
                    } } })
    expect(described_class.blocked?(agent, message)).to be(true)
  end

  it 'supports snake case participant_alt and device-qualified phone JIDs' do
    message.update!(content_attributes: { whatsapp_message_key: {
                      participant: '247613823709228@lid', participant_alt: '5562999991111:2@s.whatsapp.net'
                    } })
    expect(described_class.blocked?(agent, message)).to be(true)
  end

  it 'resolves a LID using the existing group participants mapping' do
    message.update!(content_attributes: { participant_identifier: '247613823709228@lid' })
    service = instance_double(Evolution::GroupParticipantsService, perform: [
                                { lid: '247613823709228@lid', phone: '5562999991111' }
                              ])
    allow(Evolution::GroupParticipantsService).to receive(:new).with(conversation).and_return(service)
    expect(described_class.blocked?(agent, message)).to be(true)
  end

  it 'resolves a mapped contact without treating LID digits as a phone number' do
    create(:contact, account: account, identifier: '247613823709228@lid', phone_number: '+5562999991111')
    message.update!(content_attributes: { participant: { identifier: '247613823709228@lid' } })
    allow(Evolution::GroupParticipantsService).to receive(:new).and_return(instance_double(Evolution::GroupParticipantsService, perform: []))
    expect(described_class.blocked?(agent, message)).to be(true)
    agent.group_response_blacklist = ['247613823709228']
    expect(described_class.blocked?(agent, message)).to be(false)
  end

  it 'does not guess a number for an unresolved LID' do
    message.update!(content_attributes: { participant: '247613823709228@lid' })
    allow(Evolution::GroupParticipantsService).to receive(:new).and_return(instance_double(Evolution::GroupParticipantsService, perform: []))
    agent.group_response_blacklist = ['247613823709228']
    expect(described_class.blocked?(agent, message)).to be(false)
  end

  it 'does not resolve the participant using a contact from another account' do
    create(:contact, identifier: '247613823709228@lid', phone_number: '+5562999991111')
    message.update!(content_attributes: { participant: '247613823709228@lid' })
    allow(Evolution::GroupParticipantsService).to receive(:new).and_return(instance_double(Evolution::GroupParticipantsService, perform: []))
    expect(described_class.blocked?(agent, message)).to be(false)
  end

  it 'uses the real message sender when the sender is a participant contact instead of the group contact' do
    participant = create(:contact, account: account, phone_number: '+5562999991111')
    message.update!(sender: participant, content_attributes: {})
    expect(described_class.blocked?(agent, message)).to be(true)
  end

  it 'does not use the group contact or remote JID as the participant' do
    conversation.contact.update!(phone_number: '+5562999991111')
    message.update!(content_attributes: { whatsapp_message_key: { remoteJid: '5562999991111@s.whatsapp.net' } })
    expect(described_class.blocked?(agent, message)).to be(false)
  end

  it 'keeps agents with the default empty list working' do
    agent.group_response_blacklist = []
    expect(described_class.blocked?(agent, message)).to be(false)
  end

  it 'does not apply the rule to staff replies or private notes' do
    message.update!(private: true)
    expect(described_class.blocked?(agent, message)).to be(false)
    message.update!(private: false, message_type: :outgoing, sender: create(:user, account: account))
    expect(described_class.blocked?(agent, message)).to be(false)
  end
end
