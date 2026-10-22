class Saas::AiAgents::ConversationState
  STATES = %w[ai human].freeze

  def self.update!(conversation:, state:, user:)
    raise ArgumentError, 'invalid_state' unless STATES.include?(state)

    conversation.with_lock do
      attributes = conversation.additional_attributes.deep_dup
      attributes['ai_agent_state'] = state
      if state == 'ai'
        latest_incoming = Saas::AiAgents::Context.latest_incoming(conversation)
        attributes['ai_agent_last_replied_message_id'] = latest_incoming.id if latest_incoming
        attributes.delete('ai_agent_paused_at')
        attributes.delete('ai_agent_paused_by_id')
      else
        attributes['ai_agent_paused_at'] = Time.current.iso8601
        attributes['ai_agent_paused_by_id'] = user&.id
      end
      conversation.update!(additional_attributes: attributes)
    end
    conversation
  end
end
