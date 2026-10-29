# The owner of a card follows the agent assigned to the conversation, so an agent sees the cards of the conversations
# they handle. Only the open cards of the contact move; won and lost cards keep their owner.
class Crm::DealOwnerSyncService
  def initialize(conversation:)
    @conversation = conversation
  end

  def perform
    new_owner_id = @conversation.assignee_id
    return if new_owner_id.blank?

    open_cards = @conversation.account.crm_deals.where(contact_id: @conversation.contact_id, status: 'open')
    open_cards.where.not(owner_id: new_owner_id).or(open_cards.where(owner_id: nil)).find_each { |deal| deal.update!(owner_id: new_owner_id) }
  end
end
