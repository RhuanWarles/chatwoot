class Evolution::MessageEditSyncService
  def initialize(message:, content:, instance_name:, whatsapp_message_key:, edited_at: nil)
    @message = message
    @content = content
    @instance_name = instance_name
    @whatsapp_message_key = whatsapp_message_key.to_h.stringify_keys
    @edited_at = edited_at
  end

  def perform
    validate!

    @message.with_lock do
      return @message if already_synchronized?

      attributes = updated_content_attributes
      @message.update!(content: @content, content_attributes: attributes)
    end

    @message
  end

  private

  def validate!
    raise CustomExceptions::Evolution, :message_edit_sync_invalid unless @message.inbox.api?
    raise CustomExceptions::Evolution, :message_edit_sync_invalid unless matching_evolution_instance?
    raise CustomExceptions::Evolution, :message_edit_sync_invalid unless valid_message_key?
    raise CustomExceptions::Evolution, :message_edit_sync_invalid if @content.blank?
  end

  def matching_evolution_instance?
    configured_instances = [
      @message.inbox.whatsapp_connection&.instance_name,
      @message.inbox.channel.additional_attributes['evolution_instance_name']
    ].compact

    @instance_name.present? && configured_instances.include?(@instance_name)
  end

  def valid_message_key?
    key_id = @whatsapp_message_key['id'].to_s
    return false if key_id.blank?

    stored_key = @message.content_attributes['whatsapp_message_key'].to_h.stringify_keys
    return false unless stored_key['id'].to_s == key_id
    return false unless matching_message_key_identity?(stored_key)

    source_id = @message.source_id.to_s.delete_prefix('WAID:')
    source_id.blank? || source_id == key_id
  end

  def matching_message_key_identity?(stored_key)
    incoming_from_me = key_value(@whatsapp_message_key, 'fromMe', 'from_me')
    stored_from_me = key_value(stored_key, 'fromMe', 'from_me')
    return false if !incoming_from_me.nil? && !stored_from_me.nil? && incoming_from_me != stored_from_me

    incoming_jids = message_key_jids(@whatsapp_message_key)
    stored_jids = message_key_jids(stored_key)
    incoming_jids.empty? || stored_jids.empty? || incoming_jids.intersect?(stored_jids)
  end

  def message_key_jids(key)
    %w[remoteJid remoteJidAlt participant participantAlt].filter_map do |field|
      key[field].presence || key[field.underscore].presence
    end
  end

  def key_value(key, *fields)
    fields.each do |field|
      return key[field] if key.key?(field)
    end
    nil
  end

  def updated_content_attributes
    attributes = @message.content_attributes.to_h.deep_dup.stringify_keys
    attributes['whatsapp_message_key'] = merged_message_key
    attributes['whatsapp_message_edited'] = true
    attributes['whatsapp_message_edit_source'] = edit_source
    attributes['whatsapp_message_edited_at'] = parsed_edited_at.iso8601
    attributes
  end

  def already_synchronized?
    @message.content == @content && @message.content_attributes['whatsapp_message_edited'] == true
  end

  def merged_message_key
    stored_key = @message.content_attributes['whatsapp_message_key'].to_h.stringify_keys
    stored_key.merge(@whatsapp_message_key).tap { |key| key['id'] = stored_key['id'] }
  end

  def edit_source
    @message.outgoing? ? 'whatsapp_outgoing' : 'whatsapp_incoming'
  end

  def parsed_edited_at
    Time.zone.parse(@edited_at.to_s) || Time.current
  rescue ArgumentError, TypeError
    Time.current
  end
end
