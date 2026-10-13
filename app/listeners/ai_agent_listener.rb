class AiAgentListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless Saas::AiAgents::Runtime.incoming?(message)

    conversation = message.conversation
    conversation.with_lock { Saas::AiAgents::ResponseBatch.cancel!(conversation, reason: 'new_incoming') }
    return unless Saas::AiAgents::Runtime.enabled?(conversation)
    agent = Saas::AiAgents::Runtime.agent_for(conversation)
    return unless agent

    job = Saas::AiAgents::RespondJob
    if agent.response_delay_seconds.to_i.zero?
      job.perform_later(message.account_id, message.conversation_id, message.id)
    else
      job.set(wait: agent.response_delay_seconds.to_i.seconds).perform_later(message.account_id, message.conversation_id, message.id)
    end
  end
end
