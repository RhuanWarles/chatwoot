class Evolution::LeaveGroupService
  def initialize(conversation:, user:)
    @context = Evolution::GroupContext.new(conversation)
    @user = user
  end

  def perform
    @context.conversation.with_lock do
      @context.require_member!(@context.participants)
      begin
        response = @context.client.delete('group/leaveGroup', groupJid: @context.group_jid)
      ensure
        @context.invalidate!
      end
      raise CustomExceptions::Evolution, :unconfirmed unless response['leave'] == true && response['groupJid'] == @context.group_jid

      @context.conversation.update!(additional_attributes: @context.conversation.additional_attributes.merge(
        'evolution_group_left_at' => Time.current.iso8601, 'evolution_group_left_by_id' => @user.id
      ))
    end
  end
end
