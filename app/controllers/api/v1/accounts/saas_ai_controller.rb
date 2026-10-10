class Api::V1::Accounts::SaasAiController < Api::V1::Accounts::BaseController
  include SaasAiAccess
  SETTINGS_VALIDATORS = {
    'text_mode' => ->(value) { Saas::AiSetting::MODES.include?(value) },
    'text_provider' => ->(value) { Saas::AiSetting::PROVIDERS.include?(value) },
    'text_model' => ->(value) { value.is_a?(String) && value.length <= 100 },
    'text_api_key' => ->(value) { value.nil? || (value.is_a?(String) && value.length.between?(1, 4096)) },
    'inbound_enabled' => ->(value) { [true, false].include?(value) },
    'outbound_enabled' => ->(value) { [true, false].include?(value) },
    'max_call_seconds' => ->(value) { value.is_a?(Integer) && (10..3600).cover?(value) }
  }.freeze

  before_action :check_admin_authorization?
  before_action :check_ai_access
  rescue_from CustomExceptions::SaasError, with: :render_saas_error

  def show
    settings = Current.account.saas_ai_setting || Current.account.build_saas_ai_setting
    resources = []
    resources << 'text_credits' if Current.account.feature_enabled?(:text_ai)
    resources << 'voice_seconds' if Current.account.feature_enabled?(:voice_ai)
    wallets = resources.map { |resource| Saas::Wallet.for_account(Current.account, resource) }
    render json: {
      settings: permitted_config(settings), wallets: wallets.map(&:public_data),
      text_credits_per_request: Saas::TextService.credits_per_request,
      calls: recent_calls,
      usage: recent_usage(wallets)
    }
  end

  def update
    attributes = settings_params
    settings = Current.account.saas_ai_setting || Current.account.build_saas_ai_setting
    raise CustomExceptions::SaasError, 'encryption_not_ready' if attributes.key?(:text_api_key) && !Chatwoot.encryption_configured?

    # Never reuse a key from a different provider.
    attributes[:text_api_key] = nil if attributes[:text_provider].present? && attributes[:text_provider] != settings.text_provider &&
                                       !attributes.key?(:text_api_key)
    settings.update!(attributes)
    render json: permitted_config(settings)
  end

  def calls
    id = validated_request_id
    number = params[:customer_number]
    raise CustomExceptions::SaasError, 'invalid_phone' unless number.is_a?(String) && number.match?(/\A\+[1-9]\d{6,14}\z/)

    call = Saas::VoiceService.new(Current.account).reserve!(
      direction: 'outbound', request_id: id, customer_number: number,
      contact: Current.account.contacts.find_by(phone_number: number)
    )
    Saas::StartVoiceCallJob.perform_later(call.id) if call.status == 'pending'
    render json: call.public_data, status: :accepted
  end

  def text_generations
    id = validated_request_id
    prompt = params[:prompt]
    raise CustomExceptions::SaasError, 'invalid_prompt' unless prompt.is_a?(String) && prompt.strip.present? && prompt.length <= 8000

    generation = Saas::TextService.new(Current.account).create!(prompt: prompt, request_id: id)
    Saas::GenerateTextJob.perform_later(generation.id) if generation.status == 'pending'
    render json: generation.public_data, status: :accepted
  end

  def text_generation
    render json: Current.account.saas_text_generations.find(params[:id]).public_data
  end

  private

  def check_ai_access
    return require_ai_feature(:voice) if action_name == 'calls'
    return require_ai_feature(:text) if %w[text_generations text_generation].include?(action_name)
    return if Current.account.feature_enabled?(:text_ai) || Current.account.feature_enabled?(:voice_ai)

    render json: { error: 'ai_disabled' }, status: :forbidden
  end

  def permitted_config(settings)
    config = settings.public_config.with_indifferent_access
    unless Current.account.feature_enabled?(:voice_ai)
      config = config.except(:inbound_enabled, :outbound_enabled, :max_call_seconds, :voice_ready, :voice_provider)
    end
    return config if Current.account.feature_enabled?(:text_ai)

    config.except(:text_mode, :text_provider, :text_model, :api_key_configured, :encryption_ready, :platform_text_ready)
  end

  def recent_usage(wallets)
    Saas::UsageRecord.where(wallet: wallets).includes(:wallet).order(id: :desc).limit(30).map do |record|
      record.public_data.merge(resource: record.wallet.resource)
    end
  end

  def recent_calls
    return [] unless Current.account.feature_enabled?(:voice_ai)

    Current.account.saas_voice_calls.includes(:usage_record).order(id: :desc).limit(30).map(&:public_data)
  end

  def settings_params
    input = params.require(:settings)
    allowed = SETTINGS_VALIDATORS.keys
    raise CustomExceptions::SaasError, 'invalid_settings' unless input.is_a?(ActionController::Parameters) && (input.keys - allowed).empty?

    check_setting_access(input.keys)

    input.each do |key, value|
      raise CustomExceptions::SaasError, 'invalid_settings' unless SETTINGS_VALIDATORS.fetch(key).call(value)
    end
    input.permit(*allowed).to_h.symbolize_keys
  end

  def check_setting_access(keys)
    Current.account.require_ai_feature!(:text) if keys.any? { |key| key.start_with?('text_') }
    Current.account.require_ai_feature!(:voice) if keys.intersect?(%w[inbound_enabled outbound_enabled max_call_seconds])
  end

  def validated_request_id
    value = params[:request_id]
    raise CustomExceptions::SaasError, 'invalid_request_id' unless value.is_a?(String) && value.match?(/\A[0-9a-f-]{36}\z/i)

    value
  end

  def render_saas_error(error)
    status = if %w[text_ai_disabled voice_ai_disabled].include?(error.code)
               :forbidden
             elsif error.code == 'insufficient_balance'
               :payment_required
             else
               :unprocessable_entity
             end
    render json: { error: error.code }, status: status
  end
end
