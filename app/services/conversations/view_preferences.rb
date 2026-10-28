class Conversations::ViewPreferences
  TAB_KEYS = %w[me unassigned all unanswered handoff_requested].freeze
  LEGACY_TAB_KEYS = %w[me unassigned all unanswered].freeze
  FILTER_KEYS = %w[assistant inbox tag ai].freeze

  def self.validate(value)
    return { valid: true, value: nil } if value.nil?

    value = value.to_h if value.respond_to?(:to_h)
    return invalid('conversation_view_preferences') unless value.is_a?(Hash)

    validate_sections(value)
  end

  def self.validate_sections(value)
    tabs = value['tabs'] || value[:tabs]
    filters = value['filters'] || value[:filters]
    return invalid('tabs') unless valid_boolean_hash?(tabs, TAB_KEYS) || valid_boolean_hash?(tabs, LEGACY_TAB_KEYS)

    return invalid('filters') unless valid_boolean_hash?(filters, FILTER_KEYS)

    return invalid('tabs') unless tabs.values.any?

    return invalid('filters') unless filters.values.any?

    { valid: true, value: { 'tabs' => tabs, 'filters' => filters } }
  end

  def self.valid_boolean_hash?(value, allowed_keys)
    return false unless value.is_a?(Hash)
    return false unless value.keys.map(&:to_s).sort == allowed_keys.sort

    value.values.all? { |item| item == true || item == false }
  end
  private_class_method :valid_boolean_hash?

  def self.invalid(field)
    { valid: false, field: field }
  end
  private_class_method :invalid
end
