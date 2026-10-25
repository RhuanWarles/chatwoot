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

    if @incoming.attachments.any?(&:audio?)
      return unless @agent.audio_enabled?

      transcription = Saas::Audio::TranscriptionService.new(attachment: @incoming.attachments.find(&:audio?),
                                                             account: @conversation.account, agent: @agent).perform
      unless transcription[:success]
        log('audio_transcription_failed', transcription[:error])
        return
      end
    end

    mode = @conversation.account.saas_ai_setting&.text_mode || 'platform'
    memory_context = Saas::AiAgents::Memory.prompt_context(@agent, @conversation.contact)
    usage = reserve_credits(mode)
    sources = Saas::Knowledge::Retrieval.for_agent(@agent, @incoming.content, conversation_id: @conversation.id,
                                                    incoming_message_id: @incoming.id)
    knowledge_context = Saas::Knowledge::Retrieval.messages(sources, enabled: @agent.knowledge_bases.exists?)
    @builtin_tools = Saas::AiAgents::BuiltinTools.new(agent: @agent, conversation: @conversation)
    tool_definitions, guidance = tool_context(mode)
    tool_executor = Saas::AiTools::Executor.new(account: @conversation.account, agent: @agent, conversation: @conversation)
    messages = Saas::AiAgents::Context.build(@conversation, @agent, @incoming, memory_context: memory_context, knowledge_context: knowledge_context)
    messages.insert(1, { role: 'system', content: guidance }) if guidance.present?
    result = Saas::AiAgents::Provider.for(@conversation.account, @agent.provider, mode: mode).generate(
      model: @agent.model,
      messages: messages,
      temperature: @agent.temperature.to_f,
      tools: tool_definitions,
      tool_handler: lambda { |name, arguments|
        Saas::AiAgents::BuiltinTools::NAMES.include?(name) ? @builtin_tools.call(name, arguments) : tool_executor.call(name, arguments)
      }
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

      # After a handoff the AI is paused, so later chunks would be cancelled; send a single message.
      response_content = Saas::AiAgents::Context.strip_internal_author_context(result.fetch(:content))
      raise CustomExceptions::AiAgentError, 'empty_response' if response_content.blank?

      chunks = Saas::AiAgents::MessageSplitter.call(response_content, @agent.split_response_messages && !@builtin_tools.handed_off?)
      batch_id = SecureRandom.uuid
      content_attributes = {
        'generated_by_ai' => true, 'ai_agent_id' => @agent.id, 'ai_agent_incoming_message_id' => @incoming.id,
        'ai_provider' => effective_provider(mode), 'ai_model' => effective_model(mode), 'ai_duration_ms' => duration,
        'ai_token_usage' => result.fetch(:usage), 'tool_calls_count' => result.fetch(:tool_calls_count, 0),
        'tool_names' => result.fetch(:tool_names, []), 'ai_response_batch_id' => batch_id,
        'ai_response_chunk_index' => 0, 'ai_response_chunk_count' => chunks.length
      }
      first_message = Messages::MessageBuilder.new(@agent, @conversation, {
                                                      content: chunks.first, message_type: 'outgoing', private: false,
                                                      content_type: 'text', content_attributes: content_attributes,
                                                      defer_send: chunks.length > 1
                                                    }).perform
      schedule_response_chunks(chunks, batch_id, first_message.id) if chunks.length > 1
      usage&.wallet&.settle!(usage, units: usage.reserved_units, metadata: usage_metadata(result, mode))
      @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(
        Saas::AiAgents::Runtime::STATE_KEY => @builtin_tools.handed_off? ? 'human' : 'active', CURSOR_KEY => @incoming.id,
        Saas::AiAgents::ResponseBatch::KEY => { 'id' => batch_id, 'agent_id' => @agent.id, 'incoming_message_id' => @incoming.id,
                                                'chunks' => chunks, 'first_message_id' => first_message.id, 'sent_count' => chunks.length > 1 ? 0 : 1,
                                                'status' => chunks.length > 1 ? 'pending' : 'completed',
                                                'content_attributes' => content_attributes }
      ))
      log('replied')
      true
    end
    release_usage(usage) unless persisted || usage.nil?
    enqueue_memory_update if persisted
  end

  def schedule_response_chunks(_chunks, batch_id, first_message_id)
    Saas::AiAgents::ResponseChunkJob.perform_later(@conversation.account_id, @conversation.id, batch_id, 0, first_message_id)
  end

  def enqueue_memory_update
    return unless @agent.customer_memory_enabled? && @conversation.contact

    Saas::AiAgents::MemoryJob.perform_later(
      @conversation.account_id, @agent.id, @conversation.contact_id, @conversation.id, @incoming.id
    )
  rescue StandardError => error
    Rails.logger.warn({ event: 'ai_agent_memory', account_id: @conversation.account_id, ai_agent_id: @agent.id,
                        conversation_id: @conversation.id, status: 'enqueue_failed', error: error.message }.to_json)
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
      'source' => 'runtime', 'ai_agent_id' => @agent.id, 'conversation_id' => @conversation.id, 'incoming_message_id' => @incoming.id,
      'provider' => effective_provider(mode), 'model' => effective_model(mode), 'mode' => mode,
      'prompt_tokens' => result.dig(:usage, 'prompt_tokens'), 'completion_tokens' => result.dig(:usage, 'completion_tokens'),
      'total_tokens' => result.dig(:usage, 'total_tokens'), 'tool_calls_count' => result.fetch(:tool_calls_count, 0),
      'tool_names' => result.fetch(:tool_names, []), 'duration_ms' => duration
    }.compact
  end

  def reservation_metadata(mode)
    {
      'source' => 'runtime', 'ai_agent_id' => @agent.id, 'conversation_id' => @conversation.id, 'incoming_message_id' => @incoming.id,
      'provider' => effective_provider(mode), 'model' => effective_model(mode), 'mode' => mode
    }
  end

  def tool_context(mode)
    custom = Saas::AiTools::Catalog.for_agent(@agent)
    unless Saas::AiAgents::Provider.tools_supported?(effective_provider(mode))
      log('tools_unsupported') if custom.present?
      return [[], nil]
    end

    builtin = @builtin_tools.definitions
    guidance = [Saas::AiTools::Catalog.instructions(custom), (@builtin_tools.instructions if builtin.present?)].compact.join("\n\n").presence
    [custom + builtin, guidance]
  end

  def effective_provider(mode)
    mode == 'platform' ? Saas::TextService.platform_config[:provider] : @agent.provider
  end

  def effective_model(mode)
    mode == 'platform' ? Saas::TextService.platform_config[:model] : @agent.model
  end

  def response_current?
    return false unless runtime_agent_current?

    @agent.reload.active? && @agent.updated_at == @agent_revision && latest_incoming_current?
  end

  def runtime_agent_current?
    (@builtin_tools.handed_off? || Saas::AiAgents::Runtime.enabled?(@conversation)) &&
      Saas::AiAgents::Runtime.agent_for(@conversation)&.id == @agent.id
  end

  def latest_incoming_current?
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
