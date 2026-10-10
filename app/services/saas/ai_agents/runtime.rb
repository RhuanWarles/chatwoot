class Saas::AiAgents::Runtime
  STATE_KEY = 'ai_agent_state'.freeze
  RESPONDABLE_STATUSES = %w[open pending].freeze

  def self.incoming?(message)
    message.incoming? && !message.private? && message.sender_type == 'Contact' &&
      message.content.to_s.strip.present? && message.content_attributes['generated_by_ai'] != true
  end

  def self.agent_for(conversation)
    agents = conversation.account.saas_ai_agents.where(active: true).joins(:ai_agent_inboxes)
                         .where(saas_ai_agent_inboxes: { inbox_id: conversation.inbox_id }).distinct.limit(2).to_a
    if agents.length > 1
      Rails.logger.error({ event: 'ai_agent_runtime', account_id: conversation.account_id,
                           conversation_id: conversation.id, status: 'multiple_active_agents' }.to_json)
      return
    end
    agent = agents.first
    return if agent && !agent.respond_to_groups? && conversation.contact_inbox.source_id.to_s.end_with?('@g.us')

    agent
  end

  def self.enabled?(conversation)
    account_available?(conversation.account) && conversation.additional_attributes.fetch(STATE_KEY, 'active') == 'active' &&
      RESPONDABLE_STATUSES.include?(conversation.status) && !conversation.contact.blocked? &&
      !conversation.inbox.active_bot? && conversation.ai_assignee.nil? && conversation.can_reply?
  end

  def self.account_available?(account)
    account.reload
    account.active? && account.feature_enabled?(:text_ai)
  end
  private_class_method :account_available?

  def self.pause_for_human!(message)
    conversation = message.account.conversations.find(message.conversation_id)
    return unless agent_for(conversation) || conversation.additional_attributes.key?(STATE_KEY)

    conversation.with_lock do
      conversation.update!(additional_attributes: conversation.additional_attributes.merge(
        STATE_KEY => 'human', 'ai_agent_paused_at' => Time.current.iso8601, 'ai_agent_paused_by_id' => message.sender_id
      ))
    end
  end
end
