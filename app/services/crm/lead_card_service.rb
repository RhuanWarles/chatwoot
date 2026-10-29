# Makes sure a new lead has a card: a contact that writes to us (or is created) and has no open card gets one in the
# pipeline chosen in the CRM settings, owned by whoever is assigned to the conversation.
class Crm::LeadCardService
  def initialize(contact:, conversation: nil)
    @contact = contact
    @conversation = conversation
    @account = contact.account
  end

  def perform
    return unless eligible?

    settings = Crm::AutoCardSettings.new(@account)
    return unless settings.enabled?

    pipeline, stage = settings.target(preferred_pipeline_id: ai_agent_pipeline_id)
    return unless stage

    create_card(pipeline, stage)
  end

  private

  def eligible?
    !@contact.blocked? && !group?
  end

  def group?
    @contact.additional_attributes['is_group'].present? || @contact.identifier.to_s.end_with?('@g.us') ||
      (@conversation.present? && Evolution::GroupJidResolver.call(@conversation).present?)
  end

  # The row lock on the contact makes two messages that arrive together wait for each other, so only one creates the card.
  def create_card(pipeline, stage)
    @contact.with_lock do
      next if @account.crm_deals.exists?(contact_id: @contact.id, status: 'open')

      @account.crm_deals.create!(
        contact: @contact, pipeline: pipeline, pipeline_stage: stage, name: card_name, owner_id: @conversation&.assignee_id
      )
    end
  end

  def card_name
    @contact.name.presence || @contact.phone_number.presence || @contact.email.presence || 'Lead'
  end

  def ai_agent_pipeline_id
    return if @conversation.blank?

    Saas::AiAgents::Runtime.agent_for(@conversation)&.crm_pipeline_id
  end
end
