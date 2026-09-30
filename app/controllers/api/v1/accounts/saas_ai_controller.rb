class Api::V1::Accounts::SaasAiController < Api::V1::Accounts::BaseController
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
  rescue_from CustomExceptions::SaasError, with: :render_saas_error

  def show
    settings = Current.account.saas_ai_setting || Current.account.build_saas_ai_setting
    wallets = Saas::Wallet::RESOURCES.map { |resource| Saas::Wallet.for_account(Current.account, resource) }
    render json: {
      settings: settings.public_config, wallets: wallets.map(&:public_data),
      text_credits_per_request: Saas::TextService.credits_per_request,
      calls: Current.account.saas_voice_calls.includes(:usage_record).order(id: :desc).limit(30).map(&:public_data),
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
    render json: settings.public_config
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

  def recent_usage(wallets)
    Saas::UsageRecord.where(wallet: wallets).includes(:wallet).order(id: :desc).limit(30).map do |record|
      record.public_data.merge(resource: record.wallet.resource)
    end
  end

  def settings_params
    input = params.require(:settings)
    allowed = SETTINGS_VALIDATORS.keys
    raise CustomExceptions::SaasError, 'invalid_settings' unless input.is_a?(ActionController::Parameters) && (input.keys - allowed).empty?

    input.each do |key, value|
      raise CustomExceptions::SaasError, 'invalid_settings' unless SETTINGS_VALIDATORS.fetch(key).call(value)
    end
    input.permit(*allowed).to_h.symbolize_keys
  end

  def validated_request_id
    value = params[:request_id]
    raise CustomExceptions::SaasError, 'invalid_request_id' unless value.is_a?(String) && value.match?(/\A[0-9a-f-]{36}\z/i)

    value
  end

  def render_saas_error(error)
    status = error.code == 'insufficient_balance' ? :payment_required : :unprocessable_entity
    render json: { error: error.code }, status: status
  end
end
