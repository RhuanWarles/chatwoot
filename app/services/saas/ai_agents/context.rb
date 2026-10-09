class Saas::AiAgents::Context
  HISTORY_LIMIT = 30
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

  def self.build(conversation, agent, incoming)
    remaining = HISTORY_CHARACTER_LIMIT
    history = relevant(conversation).where('id <= ?', incoming.id).reorder(id: :desc).limit(HISTORY_LIMIT).filter_map do |message|
      next if message.content_attributes['generated_by_ai'] == true && message.incoming?
      next unless remaining.positive?

      content = message.content.strip.first([MESSAGE_CHARACTER_LIMIT, remaining].min)
      next if content.blank?

      remaining -= content.length
      { role: message.incoming? ? 'user' : 'assistant', content: content }
    end.reverse
    [{ role: 'system', content: agent.system_prompt }] + history
  end
end
