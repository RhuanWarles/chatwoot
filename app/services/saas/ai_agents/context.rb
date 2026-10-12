class Saas::AiAgents::Context
  DEFAULT_HISTORY_LIMIT = 20
  MAX_HISTORY_LIMIT = 100
  HISTORY_CHARACTER_LIMIT = 24_000
  MESSAGE_CHARACTER_LIMIT = 4000

  def self.relevant(conversation)
    conversation.messages.where(private: false, message_type: %w[incoming outgoing]).where.not(content: [nil, ''])
                .where('message_type = ? OR sender_type = ?', Message.message_types.fetch('outgoing'), 'Contact')
  end

  def self.latest_incoming(conversation)
    relevant(conversation).where(message_type: :incoming).where("content ~ '[^[:space:]]'")
                          .where("COALESCE((content_attributes #>> '{}')::jsonb->>'generated_by_ai', 'false') <> 'true'")
                          .reorder(id: :desc).first
  end

  def self.build(conversation, agent, incoming, memory_context: nil, knowledge_context: [])
    remaining = HISTORY_CHARACTER_LIMIT
    limit = agent.context_messages_limit.presence || DEFAULT_HISTORY_LIMIT
    history = relevant(conversation).where('id <= ?', incoming.id).reorder(id: :desc)
                         .limit(limit.clamp(1, MAX_HISTORY_LIMIT) + 1).filter_map do |message|
      next if message.content_attributes['generated_by_ai'] == true && message.incoming?
      next unless remaining.positive?

      content = message.content.strip.first([MESSAGE_CHARACTER_LIMIT, remaining].min)
      next if content.blank?

      remaining -= content.length
      { role: message.incoming? ? 'user' : 'assistant', content: content }
    end.reverse
    system_messages = [{ role: 'system', content: agent.system_prompt }]
    system_messages << { role: 'system', content: memory_context } if memory_context.present?
    system_messages + knowledge_context + history
  end
end
