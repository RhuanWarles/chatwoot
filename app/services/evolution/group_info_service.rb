class Evolution::GroupInfoService
  def initialize(conversation)
    @context = Evolution::GroupContext.new(conversation)
  end

  def perform
    conversation = @context.conversation
    if @context.left?
      return {
        left: true, name: conversation.contact.name, picture_url: conversation.contact.avatar_url,
        participants: [], instance_admin: false, instance_member: false
      }
    end

    metadata = @context.metadata
    members = @context.participants
    own = @context.own_participant(members)
    {
      left: false, name: metadata.fetch('subject'), picture_url: conversation.contact.avatar_url,
      participants: members.map { |member| member.merge(is_self: member == own) },
      instance_admin: own&.dig(:admin) == true, instance_member: own.present?
    }
  end
end
