class Crm::DealCustomFieldValue < ApplicationRecord
  self.table_name = 'crm_deal_custom_field_values'
  belongs_to :account
  belongs_to :deal, class_name: 'Crm::Deal'
  belongs_to :custom_field, class_name: 'Crm::CustomField'
  validates :custom_field, :deal, presence: true
  validate :same_account
  validate :valid_value

  private

  def same_account
    errors.add(:deal, 'must belong to the same account') if deal && deal.account_id != account_id
    errors.add(:custom_field, 'must belong to the same account') if custom_field && custom_field.account_id != account_id
  end

  def valid_value
    return if value.blank? && !custom_field&.required
    case custom_field&.field_type
    when 'number', 'currency'
      errors.add(:value, 'must be numeric') unless value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
    when 'date'
      errors.add(:value, 'must be a valid date') unless Date.iso8601(value.to_s)
    when 'datetime'
      errors.add(:value, 'must be a valid datetime') unless Time.iso8601(value.to_s)
    when 'boolean'
      errors.add(:value, 'must be boolean') unless %w[true false 0 1].include?(value.to_s)
    when 'select', 'multiselect'
      allowed = Array(custom_field.options).map { |option| option.is_a?(Hash) ? option['value'] || option[:value] : option.to_s }
      values = custom_field.field_type == 'multiselect' ? Array(value).map(&:to_s) : [value.to_s]
      errors.add(:value, 'contains an invalid option') unless values.all? { |item| allowed.include?(item) }
    end
  rescue ArgumentError
    errors.add(:value, 'has an invalid format')
  end
end
