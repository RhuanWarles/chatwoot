class Evolution::CreateGroupService
  def initialize(inbox:, user:, subject:, participants:, request_id:)
    @inbox = inbox
    @user = user
    @subject = subject
    @participants = Evolution::ParticipantNumbers.normalize(participants)
    @request_id = request_id
    @client = Evolution::GroupClient.new(inbox)
  end

  def perform
    @claimed = false
    digest = Digest::SHA256.hexdigest([@inbox.id, @subject, @participants.sort].to_json)
    request = Evolution::GroupRequest.create_or_find_by!(account_id: @inbox.account_id, request_id: @request_id) do |record|
      record.assign_attributes(inbox: @inbox, user: @user, payload_digest: digest)
    end
    claim_creation(request, digest)
    create_remote_group(request) if @claimed
    conversation = attach_conversation(request)
    Evolution::GroupParticipantsService.new(conversation).perform(refresh: true)
    conversation
  end

  private

  def claim_creation(request, digest)
    request.with_lock do
      raise CustomExceptions::Evolution, :request_conflict unless request.payload_digest == digest && request.user_id == @user.id
      return if request.group_jid.present?
      raise CustomExceptions::Evolution, :creation_uncertain if request.attempted_at.present?

      @participants = @client.whatsapp_numbers(@participants)
      # Commit the claim before the remote mutation, even if the process dies or saving the result fails.
      request.update!(attempted_at: Time.current)
      @claimed = true
    end
  end

  def create_remote_group(request)
    payload = @client.post('group/create', { subject: @subject, participants: @participants })
    metadata = payload.key?('group') ? payload.fetch('group') : payload
    jid = metadata['id']
    raise CustomExceptions::Evolution.new(:creation_uncertain, uncertain: true) unless jid.is_a?(String) && jid.match?(/\A[\d-]+@g\.us\z/)

    request.update!(group_jid: jid, metadata: metadata)
  rescue CustomExceptions::Evolution => e
    request.update!(attempted_at: nil) unless e.uncertain
    raise CustomExceptions::Evolution, :creation_uncertain if e.uncertain

    raise
  end

  def attach_conversation(request)
    request.with_lock do
      return request.conversation if request.conversation

      contact_inbox = ContactInboxWithContactBuilder.new(
        inbox: @inbox, source_id: request.group_jid,
        contact_attributes: { name: @subject, identifier: request.group_jid, additional_attributes: { is_group: true } }
      ).perform
      conversation = contact_inbox.conversations.order(created_at: :desc).first || ConversationBuilder.new(
        contact_inbox: contact_inbox, params: { status: 'open', assignee_id: @user.id }
      ).perform
      request.update!(conversation: conversation)
      conversation
    end
  end
end
