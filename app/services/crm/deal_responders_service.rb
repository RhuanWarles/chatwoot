# For each contact, the people (user ids) and whether the AI have sent replies in the contact's conversations.
class Crm::DealRespondersService
  NO_REPLIES = { 'user_ids' => [], 'ai' => false }.freeze

  def initialize(account:, contact_ids:)
    @account = account
    @contact_ids = contact_ids.uniq
  end

  def perform
    return {} if @contact_ids.empty?

    result = Hash.new { |hash, contact_id| hash[contact_id] = { 'user_ids' => [], 'ai' => false } }
    human_pairs.each { |contact_id, user_id| result[contact_id]['user_ids'] << user_id }
    ai_contact_ids.each { |contact_id| result[contact_id]['ai'] = true }
    result.default = nil
    result
  end

  private

  def replies
    Crm::Responders.replies(@account).joins(:conversation).where(conversations: { contact_id: @contact_ids })
  end

  def human_pairs
    Crm::Responders.by_humans(replies).reorder(nil).distinct.pluck('conversations.contact_id', 'messages.sender_id')
  end

  def ai_contact_ids
    Crm::Responders.by_ai(replies).reorder(nil).distinct.pluck('conversations.contact_id')
  end
end
