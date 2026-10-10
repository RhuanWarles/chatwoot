require 'zlib'

class Saas::AiAgents::Playground
  TTL = 6.hours
  HISTORY_LIMIT = 30
  HISTORY_CHARACTER_LIMIT = 24_000
  MESSAGE_CHARACTER_LIMIT = 4000
  SESSION_ID = /\A[0-9a-f-]{36}\z/i

  def initialize(account, user, agent)
    @account = account
    @user = user
    @agent = agent
  end

  def session(session_id)
    data = load_session(session_id)
    {
      session_id: session_id,
      messages: data.fetch('messages'),
      runtime: runtime_data,
      available_credits: available_credits
    }
  end

  def message(session_id:, request_id:, prompt:)
    with_request_lock(session_id, request_id) do
      data = load_session(session_id)
      existing = data.fetch('requests')[request_id]
      return response_for(session_id, data, existing) if existing

      mode = text_mode
      usage = reserve_credits(mode, session_id, request_id)
      result = Saas::AiAgents::Provider.for(@account, @agent.provider, mode: mode).generate(
        model: effective_model(mode), messages: build_messages(data, prompt), temperature: @agent.temperature.to_f
      )
      assistant = {
        'role' => 'assistant', 'content' => result.fetch(:content), 'request_id' => request_id,
        'created_at' => Time.current.iso8601
      }
      data['messages'] = trim_history(data.fetch('messages') + [
        { 'role' => 'user', 'content' => prompt, 'request_id' => request_id, 'created_at' => Time.current.iso8601 }, assistant
      ])
      data['requests'][request_id] = assistant
      usage&.wallet&.settle!(usage, units: usage.reserved_units, metadata: usage_metadata(result, mode, session_id, request_id))
      save_session(session_id, data)
      response_for(session_id, data, assistant, result.fetch(:usage), mode)
    rescue StandardError
      release_usage(usage) if defined?(usage)
      raise
    end
  end

  def clear(session_id)
    Rails.cache.delete(cache_key(session_id))
  end

  private

  def load_session(session_id)
    data = Rails.cache.read(cache_key(session_id)) || {}
    { 'messages' => Array(data['messages']), 'requests' => data['requests'].to_h }
  end

  def save_session(session_id, data)
    Rails.cache.write(cache_key(session_id), data, expires_in: TTL)
  end

  def cache_key(session_id)
    "saas-ai-playground:#{@account.id}:#{@user.id}:#{@agent.id}:#{session_id}"
  end

  def with_request_lock(session_id, request_id)
    key = Zlib.crc32("saas-ai-playground:#{@account.id}:#{@user.id}:#{@agent.id}:#{session_id}:#{request_id}")
    ApplicationRecord.connection_pool.with_connection do |connection|
      connection.select_value("SELECT pg_advisory_lock(#{key})")
      begin
        yield
      ensure
        connection.select_value("SELECT pg_advisory_unlock(#{key})")
      end
    end
  end

  def build_messages(data, prompt)
    [{ role: 'system', content: @agent.system_prompt }] + data.fetch('messages').map do |message|
      { role: message.fetch('role'), content: message.fetch('content') }
    end + [{ role: 'user', content: prompt }]
  end

  def trim_history(messages)
    remaining = HISTORY_CHARACTER_LIMIT
    messages.last(HISTORY_LIMIT).reverse.filter_map do |message|
      content = message.fetch('content').to_s.strip.first([MESSAGE_CHARACTER_LIMIT, remaining].min)
      next if content.blank? || !remaining.positive?

      remaining -= content.length
      message.merge('content' => content)
    end.reverse
  end

  def response_for(session_id, data, assistant, usage = nil, mode = text_mode)
    {
      session_id: session_id, message: assistant, usage: usage || {},
      runtime: runtime_data(mode), available_credits: available_credits
    }
  end

  def text_mode
    @account.saas_ai_setting&.text_mode || 'platform'
  end

  def runtime_data(mode = text_mode)
    config = mode == 'platform' ? { provider: ENV['SAAS_TEXT_PROVIDER'], model: ENV['SAAS_TEXT_MODEL'] } : {}
    config = Saas::TextService.platform_config if mode == 'platform' && Saas::TextService.configured?
    provider = mode == 'platform' ? config[:provider] : @agent.provider
    model = mode == 'platform' ? config[:model] : @agent.model
    { 'mode' => mode, 'provider' => provider, 'model' => model }
  end

  def effective_model(mode)
    mode == 'platform' ? Saas::TextService.platform_config[:model] : @agent.model
  end

  def available_credits
    return nil unless text_mode == 'platform'

    Saas::Wallet.for_account(@account, 'text_credits').available_units
  end

  def reserve_credits(mode, session_id, request_id)
    return unless mode == 'platform'

    Saas::Wallet.for_account(@account, 'text_credits').reserve!(
      units: Saas::TextService.credits_per_request,
      reference: "playground:#{@account.id}:#{@user.id}:#{@agent.id}:#{session_id}:#{request_id}",
      expires_at: Time.current + 15.minutes,
      metadata: { 'source' => 'playground', 'ai_agent_id' => @agent.id, 'playground_session_id' => session_id,
                  'request_id' => request_id, 'mode' => mode, 'provider' => effective_provider(mode), 'model' => effective_model(mode) }
    )
  end

  def release_usage(usage)
    usage&.wallet&.release!(usage)
  end

  def effective_provider(mode)
    mode == 'platform' ? Saas::TextService.platform_config[:provider] : @agent.provider
  end

  def usage_metadata(result, mode, session_id, request_id)
    { 'source' => 'playground', 'ai_agent_id' => @agent.id, 'playground_session_id' => session_id,
      'request_id' => request_id, 'provider' => effective_provider(mode), 'model' => effective_model(mode), 'mode' => mode,
      'prompt_tokens' => result.dig(:usage, 'prompt_tokens'), 'completion_tokens' => result.dig(:usage, 'completion_tokens'),
      'total_tokens' => result.dig(:usage, 'total_tokens') }.compact
  end
end
