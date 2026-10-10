class Evolution::GroupJidResolver
  GROUP_JID = /\A\d+@g\.us\z/

  def self.call(conversation)
    new(conversation).call
  end

  def initialize(conversation)
    @conversation = conversation
  end

  def call
    candidates.find { |candidate| valid?(candidate) }
  end

  private

  attr_reader :conversation

  def candidates
    [
      conversation.contact&.identifier,
      conversation.additional_attributes&.[]('group_jid'),
      conversation.additional_attributes&.dig('sender', 'identifier'),
      conversation.contact_inbox&.source_id
    ]
  end

  def valid?(candidate)
    candidate.is_a?(String) && candidate.match?(GROUP_JID)
  end
end
