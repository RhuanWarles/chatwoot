class Saas::TextGeneration < ApplicationRecord
  belongs_to :account
  belongs_to :usage_record, class_name: 'Saas::UsageRecord', optional: true

  validates :request_id, presence: true, uniqueness: { scope: :account_id }
  validates :mode, inclusion: { in: Saas::AiSetting::MODES }
  validates :provider, inclusion: { in: Saas::AiSetting::PROVIDERS }
  validates :model, presence: true
  validates :prompt, presence: true, length: { maximum: 8000 }
  validates :status, inclusion: { in: %w[pending running completed failed] }

  def public_data
    attributes.slice('id', 'status', 'response', 'error_code', 'input_tokens', 'output_tokens', 'created_at')
  end
end
