class Evolution::GroupParticipantEventService
  def initialize(account:, group_jid:, action:, participant:, participant_name: nil, event_id: nil)
    @account = account
    @group_jid = group_jid
    @action = action
    @participant = participant
    @participant_name = participant_name.presence || participant
    @event_id = event_id.presence
  end

  def perform
    conversation = find_conversation
    return if conversation.blank? || duplicate_event?(conversation)

    return clear_group_left_if_instance_participant(conversation) if @action == 'add'

    mark_group_left_if_instance_participant(conversation)

    message = conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: I18n.t('conversations.activity.whatsapp_group.participant_left', participant_name: @participant_name),
      source_id: source_id,
      content_attributes: {
        activity: {
          type: 'whatsapp_group_participant_left',
          participant: @participant,
          participant_name: @participant_name
        }
      }
    )

    message
  end

  private

  def find_conversation
    Conversation.joins(:contact).where(account_id: @account).where(
      "contacts.identifier = :jid OR conversations.additional_attributes ->> 'group_jid' = :jid",
      jid: @group_jid
    ).order(id: :desc).first
  end

  def source_id
    return if @event_id.blank?

    "evolution-group-event:#{@event_id}"
  end

  def duplicate_event?(conversation)
    source_id.present? && conversation.messages.exists?(source_id: source_id)
  end

  def mark_group_left_if_instance_participant(conversation)
    instance = Evolution::GroupClient.new(conversation.inbox).instance
    owner = instance['ownerJid'].to_s.split(':').first.delete_suffix('@s.whatsapp.net')
    participant = @participant.to_s.split(':').first.delete_suffix('@s.whatsapp.net')
    return if owner.blank? || participant.blank? || owner != participant

    conversation.update!(additional_attributes: conversation.additional_attributes.merge(
      'evolution_group_left_at' => Time.current.iso8601
    ))
  rescue CustomExceptions::Evolution => e
    Rails.logger.warn("[Evolution] could not mark externally left group: #{e.class}")
  end

  def clear_group_left_if_instance_participant(conversation)
    instance = Evolution::GroupClient.new(conversation.inbox).instance
    owner = instance['ownerJid'].to_s.split(':').first.delete_suffix('@s.whatsapp.net')
    participant = @participant.to_s.split(':').first.delete_suffix('@s.whatsapp.net')
    return if owner.blank? || participant.blank? || owner != participant

    conversation.update!(additional_attributes: conversation.additional_attributes.except(
      'evolution_group_left_at', 'evolution_group_left_by_id'
    ))
  rescue CustomExceptions::Evolution => e
    Rails.logger.warn("[Evolution] could not clear rejoined group state: #{e.class}")
  end
end
