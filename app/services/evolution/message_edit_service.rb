class Evolution::MessageEditService
  EDIT_WINDOW = 15.minutes

  def self.editable?(message)
    message.outgoing? &&
      message.content_type == 'text' &&
      !message.private? &&
      !message.content_attributes['deleted'] &&
      message.created_at.present? &&
      message.created_at >= EDIT_WINDOW.ago
  end

  def initialize(message:, content:)
    @message = message
    @content = content
  end

  def perform
    validate!
    Evolution::GroupClient.new(@message.inbox).update_message(
      number: message_key.fetch('remoteJid'),
      key: message_key,
      text: formatted_content
    )
  end

  private

  def validate!
    raise CustomExceptions::Evolution, :message_not_editable unless self.class.editable?(@message)
    raise CustomExceptions::Evolution, :edit_window_expired if @message.created_at < EDIT_WINDOW.ago
    raise CustomExceptions::Evolution, :message_not_editable unless message_key['fromMe'] == true
    raise CustomExceptions::Evolution, :message_not_editable if message_key['id'].blank? || message_key['remoteJid'].blank?
    raise CustomExceptions::Evolution, :message_not_editable if @content.blank?
  end

  def message_key
    @message_key ||= stored_message_key.reverse_merge(default_message_key)
  end

  def formatted_content
    configuration = Evolution::ChatwootConfiguration.new(@message.inbox).show
    sender_name = @message.sender&.available_name.presence || @message.sender&.name.presence

    Evolution::MessageSignatureFormatter.call(
      content: @content,
      sender_name: sender_name,
      sign_msg: configuration[:sign_msg],
      sign_delimiter: configuration[:sign_delimiter]
    )
  end

  def stored_message_key
    stored_key = @message.content_attributes['whatsapp_message_key']
    return {} unless stored_key.is_a?(Hash)

    stored_key.stringify_keys.tap do |key|
      key['fromMe'] = key['from_me'] unless key.key?('fromMe')
      key['remoteJid'] ||= key['remote_jid'] || key['remoteJidAlt'] || key['remote_jid_alt']
    end
  end

  def default_message_key
    {
      'id' => @message.source_id.to_s.delete_prefix('WAID:'),
      'remoteJid' => Evolution::GroupJidResolver.call(@message.conversation) ||
        @message.conversation.contact&.identifier ||
        @message.conversation.contact_inbox&.source_id,
      'fromMe' => true
    }
  end
end
