require 'rails_helper'

RSpec.describe CrmLeadListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def message_event(message)
    Events::Base.new(Events::Types::MESSAGE_CREATED, Time.current, { message: message })
  end

  def build_message(**attributes)
    create(:message, { account: account, inbox: inbox, conversation: conversation.reload, message_type: :incoming, sender: contact }.merge(attributes))
  end

  it 'asks for a card when the contact writes' do
    expect { listener.message_created(message_event(build_message)) }
      .to have_enqueued_job(Crm::LeadCardJob).with(contact.id, conversation.id)
  end

  it 'ignores outgoing messages, private notes and messages that do not come from a contact' do
    outgoing = build_message(message_type: :outgoing, sender: create(:user, account: account))
    note = build_message(private: true)

    [outgoing, note].each do |message|
      expect { listener.message_created(message_event(message)) }.not_to have_enqueued_job(Crm::LeadCardJob)
    end
  end

  it 'asks for a card when a contact that is not a visitor is created' do
    contact.update!(contact_type: 'lead')

    expect { listener.contact_created(Events::Base.new(Events::Types::CONTACT_CREATED, Time.current, { contact: contact })) }
      .to have_enqueued_job(Crm::LeadCardJob).with(contact.id)
  end

  it 'waits for the first message of an anonymous visitor' do
    contact.update!(contact_type: 'visitor')

    expect { listener.contact_created(Events::Base.new(Events::Types::CONTACT_CREATED, Time.current, { contact: contact })) }
      .not_to have_enqueued_job(Crm::LeadCardJob)
  end

  it 'moves the cards to the agent when the conversation is assigned' do
    conversation.update!(assignee: create(:user, account: account, role: :agent))

    expect { listener.assignee_changed(Events::Base.new(Events::Types::ASSIGNEE_CHANGED, Time.current, { conversation: conversation })) }
      .to have_enqueued_job(Crm::DealOwnerSyncJob).with(conversation.id)
  end

  it 'does nothing when the conversation is left without an agent' do
    expect { listener.assignee_changed(Events::Base.new(Events::Types::ASSIGNEE_CHANGED, Time.current, { conversation: conversation })) }
      .not_to have_enqueued_job(Crm::DealOwnerSyncJob)
  end
end
