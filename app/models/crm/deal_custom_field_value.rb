class Crm::DealCustomFieldValue < ApplicationRecord
  self.table_name = 'crm_deal_custom_field_values'
  belongs_to :account
  belongs_to :deal, class_name: 'Crm::Deal'
  belongs_to :custom_field, class_name: 'Crm::CustomField'
  validate :same_account
  validate :valid_value

  def typed_value
    return nil if value.nil? || value == ''
    case custom_field.field_type
    when 'number', 'currency' then Float(value)
    when 'boolean' then value == 'true'
    when 'multiselect' then JSON.parse(value)
    else value
    end
  end

  def typed_value=(input)
    self.value = input.nil? ? nil : (input.is_a?(Array) ? input.to_json : input.to_s)
  end

  private

  def same_account
    errors.add(:deal, 'Conta invalida') if deal && deal.account_id != account_id
    errors.add(:custom_field, 'Conta invalida') if custom_field && custom_field.account_id != account_id
  end

  def valid_value
    return unless custom_field
    empty = value.nil? || value.strip.empty? || (custom_field.field_type == 'multiselect' && value == '[]')
    if empty
      errors.add(:value, 'Preencha o campo obrigatorio') if custom_field.required
      return
    end
    valid = case custom_field.field_type
            when 'number', 'currency' then value.match?(/\A-?\d+(\.\d+)?\z/) && Float(value).finite?
            when 'date' then value.match?(/\A\d{4}-\d{2}-\d{2}\z/) && Date.iso8601(value)
            when 'datetime' then Time.iso8601(value)
            when 'boolean' then %w[true false].include?(value)
            when 'select' then custom_field.options.include?(value)
            when 'multiselect'
              items = JSON.parse(value)
              items.is_a?(Array) && items.all? { |item| item.is_a?(String) && custom_field.options.include?(item) }
            else true
            end
    errors.add(:value, 'Valor invalido para o tipo ou opcoes do campo') unless valid
  rescue ArgumentError, JSON::ParserError
    errors.add(:value, 'Formato invalido')
  end
end
