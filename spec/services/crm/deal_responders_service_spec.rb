require 'rails_helper'

RSpec.describe Crm::DealRespondersService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:brenda) { create(:user, account: account, role: :agent) }
  let(:rodolpho) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:other_contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:other_conversation) { create(:conversation, account: account, inbox: inbox, contact: other_contact) }

  def reply(conversation, sender: nil, **attributes)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: sender, **attributes)
  end

  def responders(*contacts)
    described_class.new(account: account, contact_ids: contacts.map(&:id)).perform
  end

  it 'lists the people who replied to the contact' do
    reply(conversation, sender: brenda)
    reply(conversation, sender: rodolpho)
    reply(conversation, sender: brenda)

    expect(responders(contact)[contact.id]).to eq('user_ids' => [brenda.id, rodolpho.id].sort, 'ai' => false)
  end

  it 'tells when the AI replied' do
    reply(conversation, content_attributes: { 'generated_by_ai' => true })

    expect(responders(contact)[contact.id]).to eq('user_ids' => [], 'ai' => true)
  end

  it 'keeps humans and the AI of the same conversation apart' do
    reply(conversation, content_attributes: { 'generated_by_ai' => true })
    reply(conversation, sender: brenda)

    expect(responders(contact)[contact.id]).to eq('user_ids' => [brenda.id], 'ai' => true)
  end

  it 'does not count messages from the customer, private notes or other contacts' do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming)
    reply(conversation, sender: brenda, private: true)
    reply(other_conversation, sender: rodolpho)

    result = responders(contact, other_contact)

    expect(result[contact.id]).to be_nil
    expect(result[other_contact.id]).to eq('user_ids' => [rodolpho.id], 'ai' => false)
  end

  it 'does not look at other accounts' do
    other_account = create(:account)
    foreign_inbox = create(:inbox, account: other_account)
    foreign_conversation = create(:conversation, account: other_account, inbox: foreign_inbox, contact: contact)
    create(:message, account: other_account, inbox: foreign_inbox, conversation: foreign_conversation, message_type: :outgoing,
                     content_attributes: { 'generated_by_ai' => true })

    expect(responders(contact)[contact.id]).to be_nil
  end

  it 'returns nothing when there are no contacts' do
    expect(described_class.new(account: account, contact_ids: []).perform).to eq({})
  end
end
