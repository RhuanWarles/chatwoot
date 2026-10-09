class Saas::AiAgents::Respond
  LOCK_NAMESPACE = 0x4149 << 32
  CURSOR_KEY = 'ai_agent_last_replied_message_id'.freeze

  def initialize(conversation, triggering_message)
    @conversation = conversation
    @triggering_message = triggering_message
  end

  def perform
    Conversation.connection_pool.with_connection do |connection|
      key = LOCK_NAMESPACE + @conversation.id
      acquired = connection.select_value("SELECT pg_try_advisory_lock(#{key})")
      raise CustomExceptions::AiAgentError::Busy, 'conversation_busy' unless acquired

      begin
        respond
      ensure
        connection.select_value("SELECT pg_advisory_unlock(#{key})")
      end
    end
  end

  private

  def respond
    @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @conversation.reload
    return unless Saas::AiAgents::Runtime.incoming?(@triggering_message) && Saas::AiAgents::Runtime.enabled?(@conversation)

    @agent = Saas::AiAgents::Runtime.agent_for(@conversation)
    return unless @agent

    @agent_revision = @agent.updated_at
    @incoming = Saas::AiAgents::Context.latest_incoming(@conversation)
    return unless @incoming && @incoming.id > @conversation.additional_attributes.fetch(CURSOR_KEY, 0).to_i

    result = Saas::AiAgents::Provider.for(@conversation.account, @agent.provider).generate(
      model: @agent.model, messages: Saas::AiAgents::Context.build(@conversation, @agent, @incoming), temperature: @agent.temperature.to_f
    )
    persist(result)
  rescue CustomExceptions::AiAgentError => e
    log('error', e.message)
    raise
  end

  def persist(result)
    @conversation.with_lock do
      # Recheck after the network call: humans, new input and agent reconfiguration can arrive while generating.
      unless response_current?
        log('discarded_stale_response')
        return
      end
      return if @conversation.additional_attributes.fetch(CURSOR_KEY, 0).to_i >= @incoming.id

      Messages::MessageBuilder.new(@agent, @conversation, {
                                     content: result.fetch(:content), message_type: 'outgoing', private: false, content_type: 'text',
                                     content_attributes: {
                                       generated_by_ai: true, ai_agent_id: @agent.id, ai_agent_incoming_message_id: @incoming.id,
                                       ai_provider: @agent.provider, ai_model: @agent.model,
                                       ai_duration_ms: duration, ai_token_usage: result.fetch(:usage)
                                     }
                                   }).perform
      @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(
        Saas::AiAgents::Runtime::STATE_KEY => 'active', CURSOR_KEY => @incoming.id
      ))
      log('replied')
    end
  end

  def response_current?
    Saas::AiAgents::Runtime.enabled?(@conversation) && Saas::AiAgents::Runtime.agent_for(@conversation)&.id == @agent.id &&
      @agent.reload.active? && @agent.updated_at == @agent_revision &&
      Saas::AiAgents::Context.latest_incoming(@conversation)&.id == @incoming.id
  end

  def duration
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started) * 1000).round
  end

  def log(status, error = nil)
    Rails.logger.info({ event: 'ai_agent_runtime', account_id: @conversation.account_id, conversation_id: @conversation.id,
                        incoming_message_id: @incoming&.id || @triggering_message.id, ai_agent_id: @agent&.id,
                        provider: @agent&.provider, model: @agent&.model, status: status, duration_ms: duration, error: error }.to_json)
  end
end
