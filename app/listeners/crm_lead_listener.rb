# Every new lead gets a card, and the card follows the agent who handles the conversation. The work runs in its own jobs,
# so a failure here never makes the dispatcher retry the other listeners.
class CrmLeadListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless message.incoming? && !message.private? && message.sender_type == 'Contact' && !message.auto_reply_email?

    conversation = message.conversation
    Crm::LeadCardJob.perform_later(conversation.contact_id, conversation.id)
  end

  # Visitors are anonymous web widget contacts that have not written yet: their first message creates the card instead.
  def contact_created(event)
    contact = event.data[:contact]
    return if contact.blank? || contact.visitor?

    Crm::LeadCardJob.perform_later(contact.id)
  end

  def assignee_changed(event)
    conversation = event.data[:conversation]
    return if conversation.assignee_id.blank?

    Crm::DealOwnerSyncJob.perform_later(conversation.id)
  end
end
