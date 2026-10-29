class Crm::LostReason < ApplicationRecord
  self.table_name = 'crm_lost_reasons'

  belongs_to :account
  has_many :deals, class_name: 'Crm::Deal', foreign_key: :lost_reason_id, inverse_of: :lost_reason, dependent: :nullify

  normalizes :name, with: ->(value) { value.strip }
  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { scope: :account_id, case_sensitive: false }

  scope :active, -> { where(active: true) }
end
