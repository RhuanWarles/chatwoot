# Validation of the automation actions that read or write the custom fields of a deal.
module Crm::AutomationFieldValidations
  extend ActiveSupport::Concern

  private

  # Any action may carry a condition on a custom field; the action then only runs when it holds.
  def valid_condition?(condition)
    return true if condition.nil?

    condition.is_a?(Hash) && (condition.keys - Crm::Automatable::CONDITION_KEYS).empty? &&
      Crm::FieldCondition.valid_rule?(account, condition['custom_field_id'], condition['operator'], condition['value'])
  end

  def valid_assign_random?(action)
    ids = action['user_ids']
    ids.is_a?(Array) && ids.length.between?(1, Crm::Automatable::MAX_RANDOM_OWNERS) && ids.all?(Integer) && ids.uniq.length == ids.length &&
      account.users.where(id: ids).count == ids.length
  end

  def valid_set_field?(action)
    field_id = action['custom_field_id']
    field = field_id.is_a?(Integer) && account.crm_custom_fields.find_by(id: field_id)
    field.present? && field.active? && valid_field_value?(field, action['value'])
  end

  def valid_field_value?(field, value)
    stored = value.is_a?(Array) ? value.to_json : value.to_s
    stored.strip.present? && stored != '[]' && field.valid_input?(stored)
  rescue ArgumentError, JSON::ParserError
    false
  end

  def valid_route_by_field?(action)
    field_id = action['custom_field_id']
    routes = action['routes']
    field_id.is_a?(Integer) && routes.is_a?(Array) && routes.length.between?(1, Crm::Automatable::MAX_ROUTES) &&
      routes.all? { |route| valid_route?(field_id, route) } &&
      (action['fallback'].nil? || valid_destination?(action['fallback'], Crm::Automatable::DESTINATION_KEYS))
  end

  def valid_route?(field_id, route)
    route.is_a?(Hash) && valid_destination?(route, Crm::Automatable::ROUTE_KEYS) &&
      Crm::FieldCondition.valid_rule?(account, field_id, route['operator'], route['value'])
  end

  def valid_destination?(destination, allowed_keys)
    destination.is_a?(Hash) && (destination.keys - allowed_keys).empty? && valid_move_stage?(destination)
  end
end
