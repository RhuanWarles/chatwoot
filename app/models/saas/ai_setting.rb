class Saas::AiSetting < ApplicationRecord
  self.table_name = 'saas_ai_settings'

  PROVIDERS = %w[openai anthropic gemini].freeze
  MODES = %w[platform byok].freeze
  MIN_CALL_SECONDS = 10
  MAX_CALL_SECONDS = 3600

  belongs_to :account
  encrypts :text_api_key

  validates :account_id, uniqueness: true
  validates :text_mode, inclusion: { in: MODES }
  validates :text_provider, inclusion: { in: PROVIDERS }
  validates :text_model, length: { maximum: 100 }
  validates :text_model, :text_api_key, presence: true, if: -> { text_mode == 'byok' }
  validates :max_call_seconds, numericality: { only_integer: true, in: MIN_CALL_SECONDS..MAX_CALL_SECONDS }
  validates :vapi_phone_number_id, uniqueness: true, allow_nil: true

  def voice_ready?
    vapi_assistant_id.present? && vapi_phone_number_id.present? && Saas::VapiClient.configured?
  end

  def public_config
    attributes.slice('text_mode', 'text_provider', 'text_model', 'inbound_enabled', 'outbound_enabled', 'max_call_seconds').merge(
      api_key_configured: text_api_key.present?,
      encryption_ready: Chatwoot.encryption_configured?,
      platform_text_ready: Saas::TextService.configured?,
      voice_ready: voice_ready?,
      voice_provider: 'vapi'
    )
  end
end
