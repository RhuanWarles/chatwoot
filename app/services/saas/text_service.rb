class Saas::TextService
  MAX_OUTPUT_TOKENS = 1024
  OUTPUT_LIMITS = {
    'openai' => { max_completion_tokens: MAX_OUTPUT_TOKENS },
    'anthropic' => { max_tokens: MAX_OUTPUT_TOKENS },
    'gemini' => { generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS } }
  }.freeze

  def self.configured?
    Saas::AiSetting::PROVIDERS.include?(ENV.fetch('SAAS_TEXT_PROVIDER', nil)) &&
      ENV['SAAS_TEXT_MODEL'].present? && ENV['SAAS_TEXT_API_KEY'].present?
  end

  def self.platform_config
    raise CustomExceptions::SaasError, 'text_not_ready' unless configured?

    { provider: ENV.fetch('SAAS_TEXT_PROVIDER'), model: ENV.fetch('SAAS_TEXT_MODEL') }
  end

  def self.generate_messages(messages:, temperature:)
    config = platform_config
    context = RubyLLM.context do |settings|
      settings.public_send("#{config[:provider]}_api_key=", ENV.fetch('SAAS_TEXT_API_KEY'))
      settings.request_timeout = 60
      settings.max_retries = 0
    end
    chat = context.chat(model: config[:model], provider: config[:provider], assume_model_exists: true)
                  .with_temperature(temperature)
                  .with_params(**OUTPUT_LIMITS.fetch(config[:provider]))
    messages.each { |message| chat.add_message(role: message.fetch(:role).to_sym, content: message.fetch(:content)) }
    response = chat.complete
    content = response&.content
    raise CustomExceptions::SaasError, 'empty_response' unless content.is_a?(String) && content.strip.present?

    {
      content: content.strip,
      usage: {
        'prompt_tokens' => response.input_tokens,
        'completion_tokens' => response.output_tokens,
        'total_tokens' => response.input_tokens.to_i + response.output_tokens.to_i
      }.compact
    }
  end

  def self.credits_per_request
    Integer(ENV.fetch('SAAS_TEXT_CREDITS_PER_REQUEST', '1')).tap do |units|
      raise ArgumentError, 'SAAS_TEXT_CREDITS_PER_REQUEST must be positive' unless units.positive?
    end
  end

  def initialize(account)
    @account = account
  end

  def create!(prompt:, request_id:)
    wallet = Saas::Wallet.for_account(@account, 'text_credits')
    wallet.with_lock do
      existing = @account.saas_text_generations.find_by(request_id: request_id)
      if existing
        raise CustomExceptions::SaasError, 'reference_conflict' unless existing.prompt == prompt

        next existing
      end
      config = generation_config
      usage = wallet.reserve!(units: self.class.credits_per_request, reference: "text:#{request_id}") if config[:mode] == 'platform'
      @account.saas_text_generations.create!(
        **config, request_id: request_id, prompt: prompt, usage_record: usage
      )
    end
  end

  def generate(generation)
    context = RubyLLM.context do |config|
      config.public_send("#{generation.provider}_api_key=", api_key(generation))
      config.request_timeout = 60
      config.max_retries = 0
    end
    context.chat(model: generation.model, provider: generation.provider, assume_model_exists: true)
           .with_params(**OUTPUT_LIMITS.fetch(generation.provider))
           .ask(generation.prompt)
  end

  private

  def generation_config
    settings = @account.saas_ai_setting || @account.build_saas_ai_setting
    own_key = settings.text_mode == 'byok'
    ready = own_key ? settings.text_api_key.present? : self.class.configured?
    raise CustomExceptions::SaasError, 'text_not_ready' unless @account.active? && ready

    {
      mode: settings.text_mode,
      provider: own_key ? settings.text_provider : ENV.fetch('SAAS_TEXT_PROVIDER'),
      model: own_key ? settings.text_model : ENV.fetch('SAAS_TEXT_MODEL')
    }
  end

  def api_key(generation)
    return ENV.fetch('SAAS_TEXT_API_KEY') if generation.mode == 'platform'

    settings = @account.saas_ai_setting
    unless settings&.text_mode == 'byok' && settings.text_provider == generation.provider && settings.text_api_key.present?
      raise CustomExceptions::SaasError, 'text_not_ready'
    end

    settings.text_api_key
  end
end
