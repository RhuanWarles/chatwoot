class Evolution::GroupContext
  attr_reader :conversation

  def initialize(conversation)
    @conversation = conversation
  end

  def client
    @client ||= Evolution::GroupClient.new(conversation.inbox)
  end

  def group_jid
    jid = Evolution::GroupJidResolver.call(conversation)
    raise CustomExceptions::Evolution, :not_found unless jid

    jid
  end

  def left?
    conversation.additional_attributes['evolution_group_left_at'].present?
  end

  def participants(refresh: true)
    Evolution::GroupParticipantsService.new(conversation).perform(refresh: refresh, strict: true)
  end

  def invalidate!
    Evolution::GroupParticipantsService.new(conversation).invalidate!
  end

  def metadata
    payload = client.get('group/findGroupInfos', groupJid: group_jid)
    payload.key?('group') ? payload.fetch('group') : payload
  end

  def own_participant(members)
    instance = client.instance
    raise CustomExceptions::Evolution, :unavailable unless instance['connectionStatus'] == 'open'

    jid = instance.fetch('ownerJid').split(':').first.delete_suffix('@s.whatsapp.net')
    members.find { |member| member[:phone] == jid }
  end

  def require_member!(members)
    raise CustomExceptions::Evolution, :group_left if left?

    own_participant(members) || raise(CustomExceptions::Evolution, :not_a_member)
  end

  def require_admin!(members)
    own = require_member!(members)
    raise CustomExceptions::Evolution, :not_group_admin unless own[:admin]

    own
  end
end
