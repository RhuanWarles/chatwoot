class Crm::DealCustomFieldValue < ApplicationRecord
  self.table_name = 'crm_deal_custom_field_values'
  belongs_to :account
  belongs_to :deal, class_name: 'Crm::Deal'
  belongs_to :custom_field, class_name: 'Crm::CustomField'
  validate :same_account
  validate :valid_value
  after_commit :enqueue_field_automations, on: [:create, :update]

  # Set by automations so the values they write enqueue their own follow-ups one level deeper.
  attr_accessor :automation_depth

  def typed_value
    return nil if value.nil? || value == ''
    case custom_field.field_type
    when 'number', 'currency' then Float(value, exception: false)
    when 'boolean' then value == 'true'
    when 'multiselect' then JSON.parse(value)
    else value
    end
  rescue JSON::ParserError
    # The field type can change after values were saved; one stale value must not fail the whole deals list.
    nil
  end

  def typed_value=(input)
    self.value = input.nil? ? nil : (input.is_a?(Array) ? input.to_json : input.to_s)
  end

  private

  def enqueue_field_automations
    return unless saved_change_to_value?
    return if deal.pipeline.field_automations.blank?

    Crm::FieldAutomationJob.perform_later(deal_id, custom_field_id, automation_depth.to_i)
  end

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
    errors.add(:value, 'Valor invalido para o tipo ou opcoes do campo') unless custom_field.valid_input?(value)
  rescue ArgumentError, JSON::ParserError
    errors.add(:value, 'Formato invalido')
  end
end
