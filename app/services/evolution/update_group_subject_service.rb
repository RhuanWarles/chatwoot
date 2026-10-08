class Evolution::UpdateGroupSubjectService
  def initialize(conversation:, subject:)
    unless subject.is_a?(String) && subject.strip.present? && subject.strip.length <= 100
      raise CustomExceptions::Evolution, :invalid_request
    end

    @context = Evolution::GroupContext.new(conversation)
    @subject = subject.strip
  end

  def perform
    @context.conversation.with_lock do
      @context.require_admin!(@context.participants)
      begin
        response = @context.client.post('group/updateGroupSubject', { groupJid: @context.group_jid, subject: @subject })
      ensure
        @context.invalidate!
      end
      raise CustomExceptions::Evolution, :unconfirmed unless response['update'] == 'success'

      @context.conversation.contact.update!(name: @subject)
    end
  end
end
