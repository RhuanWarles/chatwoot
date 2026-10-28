class Saas::Audio::TranscriptionService
  BYTE_LIMIT = 25_000_000
  RESERVATION_TTL = 15.minutes

  def initialize(attachment:, account:, agent: nil)
    @attachment = attachment
    @account = account
    @agent = agent
  end

  def perform
    return existing_transcription if existing_transcription?

    validation_error = audio_validation_error
    return failure(validation_error) if validation_error

    usage = reserve_usage
    transcribe_and_persist(usage)
  rescue CustomExceptions::SaasError => e
    fail_usage(usage, e.code)
    failure(e.code)
  rescue Faraday::Error, OpenAI::Error => e
    fail_usage(usage, e.class.name.demodulize.underscore)
    log_provider_error(e)
    failure('provider_error')
  rescue StandardError => e
    fail_usage(usage, e.class.name.demodulize.underscore)
    log_transcription_error(e)
    failure('transcription_failed')
  end

  def self.configured?
    provider == 'openai' && model.present? && api_key.present?
  end

  # Transcribing without an AI agent (automatically or from the "Transcrever" button) is paid with the text credits.
  def self.available_for?(account)
    configured? && account.feature_enabled?(:text_ai)
  end

  def self.provider
    ENV.fetch('SAAS_AUDIO_PROVIDER', 'openai')
  end

  def self.model
    ENV.fetch('SAAS_AUDIO_MODEL', nil).presence
  end

  def self.api_key
    ENV.fetch('SAAS_AUDIO_API_KEY', nil).presence
  end

  # Why the audio cannot be transcribed right now, so a request can be refused before it is queued.
  def blocking_error
    return 'text_ai_disabled' unless @account.feature_enabled?(:text_ai)

    audio_validation_error || ('insufficient_balance' unless balance_available?)
  end

  private

  def balance_available?
    Saas::Wallet.for_account(@account, 'text_credits').available_units.positive?
  end

  def audio_validation_error
    return 'audio_not_configured' unless self.class.configured?
    return 'audio_not_attached' unless @attachment.file.attached?
    return 'audio_too_large' if audio_too_large?
  end

  def transcribe_and_persist(usage)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    text = provider.transcribe(blob: @attachment.file.blob)
    if text.blank?
      fail_usage(usage, 'empty_transcription')
      return failure('empty_transcription')
    end

    metadata = {
      'source' => 'audio_transcription', 'ai_agent_id' => @agent&.id, 'account_id' => @account.id,
      'attachment_id' => @attachment.id, 'provider' => self.class.provider, 'model' => self.class.model,
      'duration_seconds' => duration_seconds, 'audio_minutes' => duration_seconds / 60.0,
      'audio_credits_used' => usage.reserved_units, 'duration_ms' => elapsed_ms(started)
    }
    usage.wallet.settle!(usage, units: usage.reserved_units, metadata: metadata)
    persist_transcription(text)
    success(text, reused: false)
  end

  def existing_transcription?
    @existing_transcription = @attachment.meta&.[]('transcribed_text').to_s.strip
    @existing_transcription.present?
  end

  def existing_transcription
    success(@existing_transcription, reused: true)
  end

  def audio_too_large?
    @attachment.file.blob.byte_size > BYTE_LIMIT
  end

  def log_provider_error(error)
    Rails.logger.warn({ event: 'saas_audio_transcription', account_id: @account.id, ai_agent_id: @agent&.id,
                        attachment_id: @attachment.id, provider: self.class.provider, model: self.class.model,
                        status: 'provider_error', error: error.class.name.demodulize.underscore,
                        request: provider_request_metadata, provider_error: provider_error_details(error) }.to_json)
  end

  def log_transcription_error(error)
    Rails.logger.warn({ event: 'saas_audio_transcription', account_id: @account.id, ai_agent_id: @agent&.id,
                        attachment_id: @attachment.id, provider: self.class.provider, model: self.class.model,
                        status: 'error', error: error.class.name.demodulize.underscore }.to_json)
  end

  def provider
    @provider ||= Saas::Audio::Providers::OpenAi.new(api_key: self.class.api_key, model: self.class.model)
  end

  def provider_request_metadata
    provider.respond_to?(:request_metadata) ? provider.request_metadata : nil
  end

  def provider_error_details(error)
    response = error_response(error)
    provider_error = response_error(response)

    {
      http_status: response_value(response, :status), type: response_value(provider_error, :type),
      code: response_value(provider_error, :code), param: response_value(provider_error, :param),
      message: response_value(provider_error, :message)
    }
  end

  def error_response(error)
    response = error.respond_to?(:response) ? error.response : nil
    response.is_a?(Hash) ? response : {}
  end

  def response_error(response)
    body = response_value(response, :body)
    body = JSON.parse(body) if body.is_a?(String)
    error = body.is_a?(Hash) ? (body['error'] || body[:error]) : nil
    error.is_a?(Hash) ? error : {}
  rescue JSON::ParserError
    {}
  end

  def response_value(response, key)
    response[key] || response[key.to_s]
  end

  def reserve_usage
    units = [(duration_seconds / 60.0 * credits_per_minute).ceil, 1].max
    wallet = Saas::Wallet.for_account(@account, 'text_credits')
    wallet.reserve!(units: units, reference: usage_reference, expires_at: Time.current + RESERVATION_TTL,
                    metadata: { 'source' => 'audio_transcription', 'ai_agent_id' => @agent&.id,
                                'provider' => self.class.provider, 'model' => self.class.model,
                                'duration_seconds' => duration_seconds, 'audio_minutes' => duration_seconds / 60.0,
                                'audio_credits_used' => units })
  end

  def credits_per_minute
    Integer(ENV.fetch('SAAS_AUDIO_CREDITS_PER_MINUTE', '1')).tap do |units|
      raise CustomExceptions::SaasError, 'audio_invalid_credits' unless units.positive?
    end
  rescue ArgumentError
    raise CustomExceptions::SaasError, 'audio_invalid_credits'
  end

  def duration_seconds
    @duration_seconds ||= [@attachment.meta&.[]('duration'), @attachment.file.blob.metadata['duration']].compact.map(&:to_f).max.to_f
  end

  def persist_transcription(text)
    meta = @attachment.meta.to_h.deep_dup
    meta.merge!('transcribed_text' => text, 'transcription_provider' => self.class.provider,
                'transcription_model' => self.class.model, 'transcription_duration_seconds' => duration_seconds)
    @attachment.update!(meta: meta)
    broadcast_message_update
  end

  # The bubble shows the text as soon as it is saved. The credits are already settled, so a broadcast problem must not fail the run.
  def broadcast_message_update
    @attachment.message&.reload&.send_update_event
  rescue StandardError => e
    Rails.logger.warn({ event: 'saas_audio_transcription', attachment_id: @attachment.id, status: 'broadcast_failed',
                        error: e.class.name.demodulize.underscore }.to_json)
  end

  def usage_reference
    "ai_audio:#{@account.id}:#{@attachment.id}:#{@agent&.id || 'account'}"
  end

  def fail_usage(usage, error_code)
    usage&.wallet&.release!(usage, metadata: { 'error_code' => error_code })
    nil
  end

  def elapsed_ms(started)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  end

  def success(text, reused:)
    { success: true, text: text, reused: reused, provider: self.class.provider, model: self.class.model }
  end

  def failure(error)
    { success: false, error: error }
  end
end
