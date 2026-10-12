class Saas::UsageRecord < ApplicationRecord
  belongs_to :wallet, class_name: 'Saas::Wallet', optional: true
  belongs_to :account
  has_one :voice_call, class_name: 'Saas::VoiceCall', dependent: :destroy

  validates :reference, presence: true, uniqueness: { scope: :account_id }
  validates :kind, inclusion: { in: %w[credit consumption adjustment] }
  validates :status, inclusion: { in: %w[reserved settled released running completed failed] }
  validates :source, inclusion: { in: %w[runtime playground memory knowledge_embedding knowledge_retrieval] }
  validates :units, :reserved_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :sync_account_from_wallet
  before_validation :sync_analytics_attributes

  def public_data
    attributes.slice('id', 'reference', 'kind', 'status', 'units', 'reserved_units', 'source', 'provider', 'model',
                     'prompt_tokens', 'completion_tokens', 'total_tokens', 'estimated_cost_usd', 'created_at')
  end

  private

  def sync_account_from_wallet
    self.account_id ||= wallet&.account_id
  end

  def sync_analytics_attributes
    self.source ||= metadata['source'].presence || 'runtime'
    self.provider ||= metadata['provider']
    self.model ||= metadata['model']
    self.prompt_tokens ||= metadata['prompt_tokens']
    self.completion_tokens ||= metadata['completion_tokens']
    self.total_tokens ||= metadata['total_tokens']
    self.cached_tokens ||= metadata['cached_tokens']
    self.reasoning_tokens ||= metadata['reasoning_tokens']
    self.duration_ms ||= metadata['duration_ms']
    self.error_code ||= metadata['error_code']
    return unless provider.present? && model.present? && prompt_tokens.present? && completion_tokens.present?

    quote = Saas::AiPricing.quote(provider: provider, model: model, usage: {
      'prompt_tokens' => prompt_tokens, 'completion_tokens' => completion_tokens, 'cached_tokens' => cached_tokens
    })
    self.estimated_cost_usd ||= quote[:estimated_cost_usd]
    self.pricing_snapshot = quote[:snapshot] if pricing_snapshot.blank? && quote[:snapshot].present?
  end
end
