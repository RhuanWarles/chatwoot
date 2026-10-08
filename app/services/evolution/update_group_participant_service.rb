class Evolution::UpdateGroupParticipantService
  def initialize(conversation:, participants:)
    @conversation = conversation
    @participants = Evolution::ParticipantNumbers.normalize(participants)
    @client = Evolution::GroupClient.new(conversation.inbox)
  end

  def perform
    @conversation.with_lock { add_participants }
  end

  private

  def add_participants
    context = Evolution::GroupContext.new(@conversation)
    raise CustomExceptions::Evolution, :group_left if context.left?

    jid = context.group_jid

    service = Evolution::GroupParticipantsService.new(@conversation)
    current = service.perform(refresh: true, strict: true)
    numbers = @client.whatsapp_numbers(@participants)
    existing = current.flat_map { |participant| [participant[:phone], participant[:jid]&.delete_suffix('@s.whatsapp.net')] }.compact
    raise CustomExceptions::Evolution, :already_member if (numbers & existing).present?

    begin
      @client.update_participants(jid, 'add', numbers)
    ensure
      service.invalidate!
    end
    service.perform(refresh: true, strict: true)
  end
end
