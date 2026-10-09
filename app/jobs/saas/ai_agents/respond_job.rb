class Saas::AiAgents::RespondJob < ApplicationJob
  queue_as :low
  discard_on CustomExceptions::AiAgentError
  discard_on ActiveRecord::RecordNotFound
  retry_on CustomExceptions::AiAgentError::Busy, wait: 10.seconds, attempts: 10 do |job, error|
    job.log_exhausted(error)
  end
  retry_on CustomExceptions::AiAgentError::Transient, wait: :polynomially_longer, attempts: 3 do |job, error|
    job.log_exhausted(error)
  end

  def perform(account_id, conversation_id, incoming_message_id)
    conversation = Account.find(account_id).conversations.find(conversation_id)
    message = conversation.messages.find(incoming_message_id)
    Saas::AiAgents::Respond.new(conversation, message).perform
  end

  def log_exhausted(error)
    Rails.logger.warn({ event: 'ai_agent_runtime', account_id: arguments[0], conversation_id: arguments[1],
                        incoming_message_id: arguments[2], status: 'retry_exhausted', error: error.message }.to_json)
  end
end
