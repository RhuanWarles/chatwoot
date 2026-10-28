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

    phones = Saas::AiAgents::GroupParticipantPhones.new(message).call
    agent.group_response_blacklist.intersect?(phones)
  end
end
