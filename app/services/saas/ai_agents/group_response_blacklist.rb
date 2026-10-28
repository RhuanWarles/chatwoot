class Saas::AiAgents::GroupResponseBlacklist
  def self.phone(value)
    Evolution::ParticipantNumbers.normalize_phone(value, minimum_digits: 7)
  end

  def self.valid?(numbers)
    numbers.is_a?(Array) && numbers.all? { |number| phone(number).present? }
  end

  def self.blocked?(agent, message)
    return false if agent.group_response_blacklist.empty?
    return false unless message.incoming? && !message.private? && message.sender_type == 'Contact'
    return false unless Evolution::GroupJidResolver.call(message.conversation)

    participants = Saas::AiAgents::GroupParticipantPhones.new(message)
    resolution = participants.resolution
    phones = resolution[:phones]
    matched = agent.group_response_blacklist.intersect?(phones)
    Rails.logger.info({
      event: 'ai_group_blacklist_check', message_id: message.id, conversation_id: message.conversation_id,
      agent_id: agent.id, group: true, participant_source: resolution[:source],
      phone: mask_phone(phones.first), blacklist_size: agent.group_response_blacklist.size,
      blacklist_match: matched, action: matched ? 'skip' : 'respond'
    }.to_json)
    matched
  end

  def self.mask_phone(phone)
    return nil if phone.blank?

    phone.length <= 7 ? "#{phone.first(2)}***" : "#{phone.first(4)}*****#{phone.last(4)}"
  end
  private_class_method :mask_phone
end
