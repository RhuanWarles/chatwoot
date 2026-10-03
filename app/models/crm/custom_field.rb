class Crm::CustomField < ApplicationRecord
  self.table_name = 'crm_custom_fields'
  TYPES = %w[text textarea number currency date datetime boolean select multiselect].freeze

  belongs_to :account
  has_many :deal_values, class_name: 'Crm::DealCustomFieldValue', foreign_key: :custom_field_id, dependent: :restrict_with_error
  validates :name, :key, presence: true
  validates :key, format: { with: /\A[a-z0-9_]+\z/ }
  validates :field_type, inclusion: { in: TYPES }
  validates :options, presence: true, if: -> { %w[select multiselect].include?(field_type) }
  validates :key, uniqueness: { scope: :account_id }
end
