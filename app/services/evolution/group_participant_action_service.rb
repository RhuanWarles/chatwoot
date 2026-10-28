class Evolution::GroupParticipantActionService
  ACTIONS = %w[remove promote demote].freeze

  def initialize(conversation:, action:, participant_id:)
    raise CustomExceptions::Evolution, :invalid_action unless ACTIONS.include?(action) && participant_id.is_a?(String)

    @context = Evolution::GroupContext.new(conversation)
    @action = action
    @participant_id = participant_id
  end

  def perform
    @context.conversation.with_lock do
      members = @context.participants
      own = @context.require_admin!(members)
      target = members.find { |member| [member[:lid], member[:jid]].include?(@participant_id) }
      raise CustomExceptions::Evolution, :participant_not_found unless target && target[:phone].present?
      raise CustomExceptions::Evolution, :own_participant if target == own
      invalid_state = target[:super_admin] || (@action == 'promote' && target[:admin]) || (@action == 'demote' && !target[:admin])
      raise CustomExceptions::Evolution, :invalid_action if invalid_state

      begin
        @context.client.update_participants(@context.group_jid, @action, [target[:phone]])
      ensure
        @context.invalidate!
      end
      create_removal_activity(target[:display_name] || target[:phone]) if @action == 'remove'
      @context.participants
    end
  end

  private

  def create_removal_activity(participant_name)
    actor_name = Current.user&.name || I18n.t('conversations.activity.whatsapp_group.system_actor')
    Conversations::ActivityMessageJob.perform_later(
      @context.conversation,
      account_id: @context.conversation.account_id,
      inbox_id: @context.conversation.inbox_id,
      message_type: :activity,
      content: I18n.t('conversations.activity.whatsapp_group.participant_removed',
                      actor_name: actor_name, participant_name: participant_name),
      content_attributes: { activity: { type: 'whatsapp_group_participant_removed', participant_name: participant_name } }
    )
  end
end
