# Keeps one internal note on top of the conversation for every agent. A copy of the text is saved because the note may
# be far above the messages that are loaded.
class Conversations::PinnedNoteService
  CONTENT_LIMIT = 500

  def initialize(conversation)
    @conversation = conversation
  end

  # An agent chose this note on purpose, so newer notes do not take its place.
  def pin(message, user)
    pinned = snapshot(message).merge('pinned_by' => { 'id' => user.id, 'name' => user.name })
    @conversation.update!(additional_attributes: @conversation.additional_attributes.merge('pinned_note' => pinned))
  end

  # Every new internal note goes on top of the conversation, unless an agent pinned another one on purpose.
  def pin_latest(message)
    return unless message.private? && message.content.present? && !message.content_attributes['deleted']
    return if manually_pinned?

    pinned = snapshot(message).merge('auto' => true, 'author' => author(message))
    @conversation.update(additional_attributes: @conversation.additional_attributes.merge('pinned_note' => pinned))
  end

  private

  def manually_pinned?
    current = @conversation.additional_attributes['pinned_note']
    current.present? && !current['auto']
  end

  def snapshot(message)
    { 'message_id' => message.id, 'content' => message.content.to_s.truncate(CONTENT_LIMIT), 'pinned_at' => Time.current.iso8601 }
  end

  def author(message)
    sender = message.sender
    sender.present? ? { 'id' => sender.id, 'name' => sender.try(:name) } : nil
  end
end
