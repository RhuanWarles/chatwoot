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

  # `value` is the stored string form (see Crm::DealCustomFieldValue#typed_value=) and must not be empty.
  # Raises ArgumentError or JSON::ParserError for malformed values; callers decide how to report them.
  def valid_input?(value)
    case field_type
    when 'number', 'currency' then value.match?(/\A-?\d+(\.\d+)?\z/) && Float(value).finite?
    when 'date' then value.match?(/\A\d{4}-\d{2}-\d{2}\z/) && Date.iso8601(value)
    when 'datetime' then Time.iso8601(value)
    when 'boolean' then %w[true false].include?(value)
    when 'select' then options.include?(value)
    when 'multiselect'
      items = JSON.parse(value)
      items.is_a?(Array) && items.all? { |item| item.is_a?(String) && options.include?(item) }
    else true
    end
  end
end
