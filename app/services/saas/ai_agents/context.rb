class Saas::AiAgents::Context
  DEFAULT_HISTORY_LIMIT = 20
  MAX_HISTORY_LIMIT = 100
  HISTORY_CHARACTER_LIMIT = 24_000
  MESSAGE_CHARACTER_LIMIT = 4000
  AUTHOR_ATTRIBUTE_KEYS = %w[participant sender].freeze
  AUTHOR_NAME_KEYS = %w[name participant_name sender_name push_name pushName display_name].freeze
  AUTHOR_IDENTIFIER_KEYS = %w[
    name identifier participant_identifier participant_id sender_identifier sender_id remote_jid remoteJid
    remote_jid_alt remoteJidAlt jid lid
  ].freeze
  INTERNAL_AUTHOR_CONTEXT_PATTERN = /\[Participante:[^\]]+\]\s*/i

  def self.relevant(conversation, include_attachments: false)
    messages = conversation.messages.where(private: false, message_type: %w[incoming outgoing])
    attachment_messages = if include_attachments
                            Attachment.select(:message_id)
                          else
                            Attachment.where(file_type: Attachment.file_types[:audio]).select(:message_id)
                          end
    messages.where('content IS NOT NULL AND content <> ? OR id IN (?)', '', attachment_messages)
            .where('message_type = ? OR sender_type = ?', Message.message_types.fetch('outgoing'), 'Contact')
  end

  def self.latest_incoming(conversation, include_attachments: false)
    messages = relevant(conversation, include_attachments: include_attachments).where(message_type: :incoming)
    messages = messages.where("COALESCE((content_attributes #>> '{}')::jsonb->>'generated_by_ai', 'false') <> 'true'")
    messages.includes(:attachments, :sender).reorder(id: :desc)
            .find { |message| message_content(message, include_attachments: include_attachments).present? }
  end

  def self.build(conversation, agent, incoming, memory_context: nil, knowledge_context: [])
    interpret_attachments = agent.respond_to?(:attachment_interpretation_enabled?) && agent.attachment_interpretation_enabled?
    history = history_messages(conversation, incoming, agent.context_messages_limit, include_attachments: interpret_attachments)
    timezone = agent.respond_to?(:timezone) ? agent.timezone : nil
    system_messages = [{ role: 'system', content: Saas::AiAgents::TimeContext.render_legacy_now(agent.system_prompt, timezone) }]
    system_messages << { role: 'system', content: memory_context } if memory_context.present?
    system_messages + knowledge_context + [{ role: 'system', content: Saas::AiAgents::TimeContext.for_agent(agent) }] + history
  end

  def self.history_messages(conversation, incoming, configured_limit, include_attachments: false)
    remaining = HISTORY_CHARACTER_LIMIT
    limit = configured_limit.presence || DEFAULT_HISTORY_LIMIT
    relevant(conversation, include_attachments: include_attachments).where('id <= ?', incoming.id).reorder(id: :desc)
            .limit(limit.clamp(1, MAX_HISTORY_LIMIT) + 1).filter_map do |message|
      next if message.content_attributes['generated_by_ai'] == true && message.incoming?
      next unless remaining.positive?

      payload = message_payload(message, include_attachments: include_attachments)
      content = payload[:content].to_s.first([MESSAGE_CHARACTER_LIMIT, remaining].min)
      next if content.blank?

      remaining -= content.length
      payload.merge(role: message.incoming? ? 'user' : 'assistant', content: content)
    end.reverse
  end
  private_class_method :history_messages

  def self.message_content(message, include_attachments: false, attachment_data: nil)
    content = message.content_for_llm.to_s.strip
    attachment_data ||= Saas::AiAgents::AttachmentInterpreter.call(message) if include_attachments
    attachment_text = attachment_data&.[](:text)
    return if content.blank? && attachment_text.blank? && attachment_data&.[](:images).blank?

    [author_context(message), content.presence, attachment_text].compact.join("\n")
  end

  def self.message_payload(message, include_attachments: false)
    attachment_data = Saas::AiAgents::AttachmentInterpreter.call(message) if include_attachments
    payload = { content: message_content(message, include_attachments: include_attachments, attachment_data: attachment_data) }
    return payload unless include_attachments

    images = attachment_data[:images]
    payload[:attachments] = images if images.present?
    payload
  end

  def self.strip_internal_author_context(content)
    content.to_s.gsub(INTERNAL_AUTHOR_CONTEXT_PATTERN, '').strip
  end

  def self.author_context(message)
    metadata = message_metadata(message)
    sender = message.sender
    participant = participant_metadata(metadata)
    name = first_present(participant.values_at(*AUTHOR_NAME_KEYS), metadata.values_at(*AUTHOR_NAME_KEYS), sender.try(:name))
    identifier = first_present(participant.values_at(*AUTHOR_IDENTIFIER_KEYS), metadata.values_at(*AUTHOR_IDENTIFIER_KEYS),
                               sender_identifier(sender))

    "[Participante: #{name.presence || (message.incoming? ? 'Contato' : 'Atendente')}; " \
      "identificador: #{identifier.presence || 'não informado'}]"
  end

  def self.participant_metadata(metadata)
    participant = metadata.values_at(*AUTHOR_ATTRIBUTE_KEYS).find(&:present?)
    return { 'identifier' => participant } if participant.is_a?(String)
    return participant.to_h.stringify_keys if participant.respond_to?(:to_h)

    {}
  end
  private_class_method :participant_metadata

  def self.sender_identifier(sender)
    [sender.try(:identifier), sender.try(:phone_number), sender.try(:email),
     sender.try(:id) && "#{sender.class.name}:#{sender.id}"]
  end
  private_class_method :sender_identifier

  def self.message_metadata(message)
    [message.additional_attributes, message.content_attributes].filter_map do |attributes|
      attributes.respond_to?(:to_h) ? attributes.to_h.stringify_keys : nil
    end.reduce({}, :merge)
  end
  private_class_method :message_metadata

  def self.first_present(*values)
    values.flatten.find(&:present?).to_s.presence
  end
  private_class_method :first_present
end
