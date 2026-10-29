class Crm::DealOwnerSyncJob < ApplicationJob
  queue_as :medium

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?

    Crm::DealOwnerSyncService.new(conversation: conversation).perform
  end
end
