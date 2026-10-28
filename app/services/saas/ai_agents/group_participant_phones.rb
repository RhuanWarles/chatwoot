# A group's Contact represents the group, not the author of an incoming message.
class Saas::AiAgents::GroupParticipantPhones
  PARTICIPANT_KEYS = %w[
    participant participantAlt participant_alt participant_identifier participant_phone participant_phone_number
    remoteJidAlt remote_jid_alt sender sender_identifier sender_phone sender_phone_number
  ].freeze
  IDENTITY_KEYS = %w[
    identifier jid lid id phone phone_number phoneNumber participant participantAlt participant_alt
    remote_jid remoteJid remote_jid_alt remoteJidAlt
  ].freeze
  PHONE_JID = /\A(\d+)(?::\d+)?@s\.whatsapp\.net\z/

  def initialize(message)
    @message = message
  end

  def call
    resolution[:phones]
  end

  def resolution
    identities = participant_identities
    phone_matches = identities.filter_map do |source, identity|
      normalized = phone(identity)
      [source, normalized] if normalized
    end
    return { phones: phone_matches.map(&:last).uniq, source: phone_matches.first&.first || 'unknown' } if phone_matches.any?

    lids = identities.filter_map { |source, identity| identity if lid?(identity) }
    return { phones: [], source: 'unknown' } if lids.empty?

    mapped = mapped_phones(lids)
    { phones: mapped, source: mapped.any? ? 'lid_mapping' : 'lid_unresolved' }
  end

  private

  def mapped_phones(lids)
    contacts = @message.account.contacts.where(identifier: lids).pluck(:phone_number)
    phones = contacts.filter_map { |number| phone(number) }
    return phones.uniq if phones.any?

    members = Evolution::GroupParticipantsService.new(@message.conversation).perform
    members.filter_map { |member| phone(member[:phone]) if lids.include?(member[:lid]) }.uniq
  end

  def participant_identities
    metadata = [@message.additional_attributes, @message.content_attributes].filter_map do |attributes|
      attributes.respond_to?(:to_h) ? attributes.to_h.stringify_keys : nil
    end
    identities = metadata.flat_map { |attributes| nested_participant_identities(attributes) }
    sender = @message.sender
    if sender && sender.id != @message.conversation.contact_id
      identities.concat([['sender.identifier', sender.identifier], ['sender.phone_number', sender.phone_number]])
    end
    identities.select { |_source, value| value.is_a?(String) && value.present? }.uniq
  end

  def nested_participant_identities(value, path = 'metadata')
    case value
    when Hash
      value.flat_map do |key, nested|
        key = key.to_s
        if PARTICIPANT_KEYS.include?(key)
          extract_identity_values(nested, "#{path}.#{key}")
        else
          nested_participant_identities(nested, path)
        end
      end
    when Array
      value.flat_map { |nested| nested_participant_identities(nested, path) }
    else
      []
    end
  end

  def extract_identity_values(value, source)
    return [[source, value]] if value.is_a?(String)
    return [] unless value.respond_to?(:to_h)

    value.to_h.stringify_keys.filter_map do |key, nested|
      next unless IDENTITY_KEYS.include?(key)

      nested.is_a?(String) ? ["#{source}.#{key}", nested] : nil
    end
  end

  def phone(identity)
    value = identity.to_s
    return if lid?(value) || value.match?(/@(g\.us|broadcast)\z/)

    match = PHONE_JID.match(value)
    Saas::AiAgents::GroupResponseBlacklist.phone(match ? match[1] : value)
  end

  def lid?(value)
    value.to_s.match?(/\A\d+@lid\z/)
  end
end
