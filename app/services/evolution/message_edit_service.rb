class Evolution::MessageEditService
  EDIT_WINDOW = 15.minutes

  def self.editable?(message)
    message.outgoing? &&
      message.content_type == 'text' &&
      !message.private? &&
      !message.content_attributes['deleted'] &&
      message.source_id.present? &&
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
      text: @content
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
    @message_key ||= begin
      stored_key = @message.content_attributes['whatsapp_message_key']
      key = stored_key.is_a?(Hash) ? stored_key.stringify_keys : {}
      key.reverse_merge(
        'id' => @message.source_id.to_s.delete_prefix('WAID:'),
        'remoteJid' => Evolution::GroupJidResolver.call(@message.conversation) ||
                       @message.conversation.contact&.identifier ||
                       @message.conversation.contact_inbox&.source_id
      )
    end
  end
end
