require 'rails_helper'

RSpec.describe Evolution::GroupJidResolver do
  let(:contact) { instance_double(Contact, identifier: contact_identifier) }
  let(:contact_inbox) { instance_double(ContactInbox, source_id: source_id) }
  let(:conversation) do
    instance_double(
      Conversation,
      contact: contact,
      contact_inbox: contact_inbox,
      additional_attributes: additional_attributes
    )
  end
  let(:additional_attributes) { {} }
  let(:contact_identifier) { '120363000000001@g.us' }
  let(:source_id) { 'contact-source-uuid' }

  subject(:group_jid) { described_class.call(conversation) }

  it 'prefers the contact identifier when it is a group JID' do
    expect(group_jid).to eq('120363000000001@g.us')
  end

  it 'falls back to a group source_id' do
    allow(contact).to receive(:identifier).and_return('5511999999999@s.whatsapp.net')
    allow(contact_inbox).to receive(:source_id).and_return('120363000000002@g.us')

    expect(group_jid).to eq('120363000000002@g.us')
  end

  it 'uses a group identifier in conversation metadata when available' do
    allow(contact).to receive(:identifier).and_return('5511999999999@s.whatsapp.net')
    allow(conversation).to receive(:additional_attributes).and_return('group_jid' => '120363000000003@g.us')

    expect(group_jid).to eq('120363000000003@g.us')
  end

  it 'returns nil when no candidate is a group JID' do
    allow(contact).to receive(:identifier).and_return('123456789@lid')

    expect(group_jid).to be_nil
  end

  it 'does not treat an individual WhatsApp identifier as a group' do
    allow(contact).to receive(:identifier).and_return('5511999999999@s.whatsapp.net')

    expect(group_jid).to be_nil
  end
end
