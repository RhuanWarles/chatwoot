class Workflows::Actions::ConversationActions
  NAMES = %w[send_message add_private_note assign_agent assign_team add_label remove_label change_status change_priority].freeze

  def initialize(context, workflow)
    @context = context
    @workflow = workflow
  end

  def send_message(params)
    post_message(params, private_note: false)
  end

  def add_private_note(params)
    post_message(params, private_note: true)
  end

  def assign_agent(params)
    agent_id = id_or_keyword(params, 'agent_id')
    service.assign_agent([agent_id])
    ensure_assigned!(:assignee_id, agent_id, 'the agent is not in the inbox or has not confirmed the account')
    nil
  end

  def assign_team(params)
    team_id = id_or_keyword(params, 'team_id')
    service.assign_team([team_id])
    ensure_assigned!(:team_id, team_id, 'the team does not belong to the account')
    nil
  end

  def add_label(params)
    service.add_label(Array(params['labels']))
    nil
  end

  def remove_label(params)
    service.remove_label(Array(params['labels']))
    nil
  end

  def change_status(params)
    service.change_status([params['status']])
    nil
  end

  def change_priority(params)
    service.change_priority([params['priority'].presence || 'nil'])
    nil
  end

  private

  def conversation
    @context.conversation || raise(Workflows::ActionRunner::MissingRecord, 'No conversation is available for this run')
  end

  # The existing conversation actions already enforce inbox membership, confirmation and the like.
  def service
    ::ActionService.new(conversation)
  end

  def post_message(params, private_note:)
    content = params['content'].to_s
    raise ArgumentError, 'content is required' if content.blank?

    message = Messages::MessageBuilder.new(
      nil, conversation, { content: content, private: private_note, content_attributes: { automation_workflow_id: @workflow.id } }
    ).perform
    { 'message_id' => message.id }
  end

  # The conversation actions skip silently when the assignee is not allowed; a workflow should show that as an error.
  def ensure_assigned!(attribute, id, reason)
    return unless id.is_a?(Integer)

    raise ArgumentError, "could not assign #{id}: #{reason}" unless conversation.reload.public_send(attribute) == id
  end

  # An id, or the keywords the conversation actions understand ('nil', 'last_responding_agent').
  def id_or_keyword(params, key)
    value = params[key].to_s
    raise ArgumentError, "#{key} is required" if value.blank?

    value.match?(/\A\d+\z/) ? value.to_i : value
  end
end
