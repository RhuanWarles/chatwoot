class Messages::GroupMentionsValidator
  IDENTIFIER = /\A\d+@(lid|s\.whatsapp\.net)\z/
  FIELDS = %w[lid jid phone display_name start end].freeze

  def initialize(conversation, params)
    @conversation = conversation
    @params = params
  end

  def validate!
    attributes = parse_attributes
    return unless attributes&.key?('whatsapp_mentions')

    mentions = attributes['whatsapp_mentions']
    invalid! unless mentions.is_a?(Array) && mentions.present? && eligible?

    participants = Evolution::GroupParticipantsService.new(@conversation).perform
    invalid! unless @params[:content].is_a?(String)

    previous_end = 0
    normalized = mentions.map do |mention|
      validated = normalize_mention(mention, participants, previous_end)
      previous_end = validated[:end]
      validated
    end
    @params[:content_attributes] = attributes.merge('whatsapp_mentions' => normalized)
  end

  private

  def parse_attributes
    raw = @params[:content_attributes]
    attributes = raw.is_a?(String) ? JSON.parse(raw) : raw
    attributes = attributes.to_unsafe_h if attributes.is_a?(ActionController::Parameters)
    attributes.stringify_keys if attributes.is_a?(Hash)
  rescue JSON::ParserError
    # Preserve MessageBuilder's existing behavior for malformed legacy attributes.
    nil
  end

  def canonical_participant(mention, participants)
    invalid! unless mention.is_a?(Hash) && (mention.keys - FIELDS).empty?
    identifier = mention['lid'].presence || mention['jid']
    invalid! unless identifier.is_a?(String) && identifier.match?(IDENTIFIER)

    participants.find { |item| (item[:lid].presence || item[:jid]) == identifier } || invalid!
  end

  def normalize_mention(mention, participants, previous_end)
    participant = canonical_participant(mention, participants)
    start = mention['start']
    finish = mention['end']
    name = mention['display_name']
    invalid! unless start.is_a?(Integer) && finish.is_a?(Integer) && name.is_a?(String) && name.present?
    invalid! unless start >= previous_end && finish > start && finish <= @params[:content].length
    invalid! unless @params[:content][start...finish] == "@#{name}"

    participant.slice(:lid, :jid, :phone).merge(display_name: name, start: start, end: finish)
  end

  def eligible?
    return false if ActiveModel::Type::Boolean.new.cast(@params[:private])
    return false unless (@params[:message_type] || 'outgoing') == 'outgoing'
    return false unless @conversation.inbox.api?

    source_id = @conversation.contact_inbox.source_id.to_s
    source_id.end_with?('@g.us') || @conversation.contact.identifier.to_s.end_with?('@g.us')
  end

  def invalid!
    raise ArgumentError, I18n.t('conversations.messages.invalid_group_mentions')
  end
end
