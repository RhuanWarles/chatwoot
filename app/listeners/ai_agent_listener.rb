class AiAgentListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless Saas::AiAgents::Runtime.incoming?(message)

    conversation = message.conversation
    return unless Saas::AiAgents::Runtime.enabled?(conversation) && Saas::AiAgents::Runtime.agent_for(conversation)

    Saas::AiAgents::RespondJob.perform_later(message.account_id, message.conversation_id, message.id)
  end
end
