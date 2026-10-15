class Evolution::MessageReactionsService
  ATTRIBUTE = 'whatsapp_reactions'.freeze

  def initialize(message)
    @message = message
    @conversation = message.conversation
    @context = Evolution::GroupContext.new(@conversation)
  end

  def receive!(event)
    identity = participant(event.fetch('participant'), event.fetch('from_me'), event['name'])
    store!(identity, event.fetch('emoji'), event.fetch('timestamp_ms'), event.fetch('event_id'))
  end

  def send!(emoji, user)
    validate_outgoing!(emoji, user)
    verify_binding!
    response = @context.client.post('message/sendReaction', { key: message_key, reaction: emoji })
    identity = { 'participant_key' => 'self', 'from_me' => true, 'user_id' => user.id,
                 'display_name' => user.name, 'avatar_url' => user.avatar_url }
    store!(identity, emoji, provider_timestamp(response), response.fetch('key').fetch('id'))
  end

  private

  def verify_binding!
    configuration = @context.client.get('chatwoot/find')
    valid = configuration.fetch('accountId') == @message.account_id.to_s &&
            configuration.fetch('url').delete_suffix('/') == ENV.fetch('FRONTEND_URL').delete_suffix('/')
    raise CustomExceptions::Evolution, :permission_denied unless valid
  end

  def validate_outgoing!(emoji, user)
    raise CustomExceptions::Evolution, :group_left if @context.left?
    raise CustomExceptions::Evolution, :invalid_reaction if @message.private? || @message.content_attributes['deleted']

    verify_removal_owner!(emoji, user)
  end

  def verify_removal_owner!(emoji, user)
    return unless emoji.empty?

    owner_id = Array(@message.content_attributes[ATTRIBUTE]).find { |reaction| reaction['from_me'] }&.[]('user_id')
    return if owner_id.blank? || owner_id == user.id

    raise CustomExceptions::Evolution, :permission_denied
  end

  def provider_timestamp(response)
    value = response.dig('message', 'reactionMessage', 'senderTimestampMs')
    timestamp = if value.is_a?(Hash)
                  ((value.fetch('high') & 0xffffffff) << 32) | (value.fetch('low') & 0xffffffff)
                else
                  value.to_i
                end
    timestamp.positive? ? timestamp : response.fetch('messageTimestamp').to_i * 1000
  end

  def message_key
    id = @message.source_id.to_s.delete_prefix('WAID:')
    raise CustomExceptions::Evolution, :not_found if id.blank?

    key = @message.content_attributes['whatsapp_message_key'] || lookup_key(id)
    raise CustomExceptions::Evolution, :not_found unless valid_key?(key, id)

    key.slice('id', 'remoteJid', 'fromMe', 'participant')
  end

  def lookup_key(id)
    response = @context.client.post('chat/findMessages', { where: { key: { id: id, remoteJid: @context.group_jid } }, offset: 1, page: 1 })
    response.fetch('messages').fetch('records').find { |record| record.dig('key', 'id') == id }&.fetch('key')
  end

  def valid_key?(key, id)
    key && key['id'] == id && key['remoteJid'] == @context.group_jid && [true, false].include?(key['fromMe'])
  end

  def participant(jid, from_me, name)
    if from_me
      return { 'participant_key' => 'self', 'from_me' => true,
               'display_name' => name.presence || I18n.t('evolution_groups.reactions.connected_account') }
    end

    jid = jid.sub(/:\d+(?=@)/, '')
    member = resolve_member(jid)
    { 'participant_key' => member[:jid].presence || member[:lid].presence || jid,
      'provider_identity' => jid, 'identities' => [jid, member[:jid], member[:lid]].compact.uniq,
      'from_me' => false, 'display_name' => member[:display_name].presence || name.presence || fallback_name(jid),
      'avatar_url' => member[:avatar_url], 'contact_id' => member[:contact_id] }
  end

  def fallback_name(jid)
    jid.end_with?('@s.whatsapp.net') ? "+#{jid.delete_suffix('@s.whatsapp.net')}" : I18n.t('evolution_groups.reactions.participant')
  end

  def resolve_member(jid)
    Evolution::GroupParticipantsService.new(@conversation).perform.find { |item| [item[:lid], item[:jid]].include?(jid) } || {}
  end

  def store!(identity, emoji, timestamp, event_id)
    changed = false
    @message.with_lock do
      records = Array(@message.content_attributes[ATTRIBUTE]).map(&:dup)
      updated = updated_records(records, identity, emoji, timestamp, event_id)
      next unless updated

      # Bypass ordinary Message callbacks: reactions must not notify bots, send
      # delivery webhooks or change conversation activity/unread state.
      @message.update_columns(content_attributes: @message.content_attributes.merge(ATTRIBUTE => updated)) # rubocop:disable Rails/SkipsModelValidations
      changed = true
    end
    Rails.configuration.dispatcher.dispatch('message.reaction_updated', Time.current, message: @message, previous_changes: {}) if changed
    @message.content_attributes[ATTRIBUTE] || []
  end

  def updated_records(records, identity, emoji, timestamp, event_id)
    identities = identity['identities'] || [identity.fetch('participant_key')]
    matching = records.select { |record| identities.include?(record['participant_key']) || identities.include?(record['provider_identity']) }
    previous = matching.max_by { |record| record['timestamp_ms'].to_i }
    return reconcile_existing(records, matching, identity, event_id) if stale_event?(previous, timestamp, event_id)

    (records - matching) + [identity.merge('emoji' => emoji, 'timestamp_ms' => timestamp, 'event_id' => event_id)]
  end

  def stale_event?(previous, timestamp, event_id)
    previous && (previous['timestamp_ms'].to_i > timestamp || previous['event_id'] == event_id)
  end

  def reconcile_existing(records, matching, identity, event_id)
    previous = matching.max_by { |record| record['timestamp_ms'].to_i }
    # An echo can precede the send response; enrich that same event with the
    # operator. A different later phone event must not inherit that operator.
    if metadata_echo?(previous, identity, event_id)
      updated = previous.merge(identity)
    elsif matching.length > 1
      updated = previous.merge(identity.slice('participant_key', 'identities'))
    else
      return
    end
    (records - matching) + [updated]
  end

  def metadata_echo?(previous, identity, event_id)
    identity['user_id'].present? && previous['event_id'] == event_id && previous['user_id'].nil?
  end
end
