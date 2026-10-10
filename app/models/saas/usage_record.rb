class Saas::UsageRecord < ApplicationRecord
  belongs_to :wallet, class_name: 'Saas::Wallet'
  has_one :voice_call, class_name: 'Saas::VoiceCall', dependent: :destroy

  validates :reference, presence: true, uniqueness: { scope: :wallet_id }
  validates :kind, inclusion: { in: %w[credit consumption adjustment] }
  validates :status, inclusion: { in: %w[reserved settled released] }
  validates :units, :reserved_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def public_data
    attributes.slice('id', 'reference', 'kind', 'status', 'units', 'reserved_units', 'created_at')
  end
end
