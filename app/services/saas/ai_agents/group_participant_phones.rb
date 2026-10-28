# A group's Contact represents the group, not the author of an incoming message.
class Saas::AiAgents::GroupParticipantPhones
  PARTICIPANT_KEYS = %w[
    participant participantAlt participant_alt participant_identifier participant_phone participant_phone_number
    sender sender_identifier sender_phone sender_phone_number
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
    identities = participant_identities
    phones = identities.filter_map { |identity| phone(identity) }
    lids = identities.grep(/@lid\z/)
    return phones.uniq if phones.any? || lids.empty?

    mapped_phones(lids)
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
    metadata = @message.additional_attributes.merge(@message.content_attributes)
    key = metadata['whatsapp_message_key']
    sources = key.is_a?(Hash) ? [metadata, key] : [metadata]
    values = sources.flat_map { |source| source.values_at(*PARTICIPANT_KEYS) }
    identities = values.flat_map { |value| value.is_a?(Hash) ? value.values_at(*IDENTITY_KEYS) : value }
    sender = @message.sender
    identities.push(sender.identifier, sender.phone_number) if sender && sender.id != @message.conversation.contact_id
    identities.grep(String).uniq
  end

  def phone(identity)
    value = identity.to_s
    match = PHONE_JID.match(value)
    Saas::AiAgents::GroupResponseBlacklist.phone(match ? match[1] : value)
  end
end
