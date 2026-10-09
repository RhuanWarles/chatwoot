class Saas::VoiceAgent < ApplicationRecord
  self.table_name = 'saas_voice_agents'

  PROVIDERS = %w[vapi].freeze
  DURATION_RANGE = Saas::AiSetting::MIN_CALL_SECONDS..Saas::AiSetting::MAX_CALL_SECONDS

  belongs_to :account

  validates :name, :provider, presence: true
  validates :name, :assistant_id, :phone_number_id, length: { maximum: 100 }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :active, :inbound_enabled, :outbound_enabled, inclusion: { in: [true, false] }
  validates :max_call_duration, numericality: { only_integer: true, in: DURATION_RANGE }, allow_nil: true

  def public_data
    attributes.slice('id', 'account_id', 'name', 'description', 'provider', 'active', 'assistant_id', 'phone_number_id',
                     'inbound_enabled', 'outbound_enabled', 'max_call_duration', 'created_at', 'updated_at')
  end
end
