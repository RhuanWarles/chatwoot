class Crm::LeadCardJob < ApplicationJob
  queue_as :medium

  def perform(contact_id, conversation_id = nil)
    contact = Contact.find_by(id: contact_id)
    return if contact.blank?

    Crm::LeadCardService.new(contact: contact, conversation: Conversation.find_by(id: conversation_id)).perform
  end
end
