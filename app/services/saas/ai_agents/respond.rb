class Saas::AiAgents::Respond
  LOCK_NAMESPACE = 0x4149 << 32
  CURSOR_KEY = 'ai_agent_last_replied_message_id'.freeze
  RESERVATION_TTL = 15.minutes

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

    mode = @conversation.account.saas_ai_setting&.text_mode || 'platform'
    usage = reserve_credits(mode)
    result = Saas::AiAgents::Provider.for(@conversation.account, @agent.provider, mode: mode).generate(
      model: @agent.model, messages: Saas::AiAgents::Context.build(@conversation, @agent, @incoming), temperature: @agent.temperature.to_f
    )
    persist(result, usage, mode: mode)
  rescue CustomExceptions::SaasError => e
    log('credit_unavailable', e.code)
  rescue CustomExceptions::AiAgentError => e
    release_usage(@usage_record, error_code: e.message)
    log('error', e.message)
    raise
  rescue StandardError => e
    release_usage(@usage_record, error_code: e.class.name.demodulize.underscore)
    raise
  end

  def persist(result, usage, mode:)
    persisted = @conversation.with_lock do
      # Recheck after the network call: humans, new input and agent reconfiguration can arrive while generating.
      unless response_current?
        log('discarded_stale_response')
        next false
      end
      next false if @conversation.additional_attributes.fetch(CURSOR_KEY, 0).to_i >= @incoming.id

      Messages::MessageBuilder.new(@agent, @conversation, {
                                     content: result.fetch(:content), message_type: 'outgoing', private: false, content_type: 'text',
                                     content_attributes: {
                                       generated_by_ai: true, ai_agent_id: @agent.id, ai_agent_incoming_message_id: @incoming.id,
                                       ai_provider: effective_provider(mode), ai_model: effective_model(mode),
                                       ai_duration_ms: duration, ai_token_usage: result.fetch(:usage)
                                     }
                                   }).perform
      usage&.wallet&.settle!(usage, units: usage.reserved_units, metadata: usage_metadata(result, mode))
      @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(
        Saas::AiAgents::Runtime::STATE_KEY => 'active', CURSOR_KEY => @incoming.id
      ))
      log('replied')
      true
    end
    release_usage(usage) unless persisted || usage.nil?
  end

  def reserve_credits(mode)
    return unless mode == 'platform'

    @usage_record = Saas::Wallet.for_account(@conversation.account, 'text_credits').reserve!(
      units: Saas::TextService.credits_per_request,
      reference: reservation_reference,
      expires_at: Time.current + RESERVATION_TTL,
      metadata: reservation_metadata(mode)
    )
  end

  def release_usage(usage, error_code: nil)
    return unless usage

    metadata = error_code ? { 'error_code' => error_code } : {}
    usage.wallet.release!(usage, metadata: metadata)
  end

  def reservation_reference
    "ai_agent:#{@conversation.account_id}:#{@conversation.id}:#{@incoming.id}:#{@agent.id}"
  end

  def usage_metadata(result, mode)
    {
      'ai_agent_id' => @agent.id, 'conversation_id' => @conversation.id, 'incoming_message_id' => @incoming.id,
      'provider' => effective_provider(mode), 'model' => effective_model(mode), 'mode' => mode,
      'prompt_tokens' => result.dig(:usage, 'prompt_tokens'), 'completion_tokens' => result.dig(:usage, 'completion_tokens'),
      'total_tokens' => result.dig(:usage, 'total_tokens'), 'duration_ms' => duration
    }.compact
  end

  def reservation_metadata(mode)
    {
      'ai_agent_id' => @agent.id, 'conversation_id' => @conversation.id, 'incoming_message_id' => @incoming.id,
      'provider' => effective_provider(mode), 'model' => effective_model(mode), 'mode' => mode
    }
  end

  def effective_provider(mode)
    mode == 'platform' ? Saas::TextService.platform_config[:provider] : @agent.provider
  end

  def effective_model(mode)
    mode == 'platform' ? Saas::TextService.platform_config[:model] : @agent.model
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
