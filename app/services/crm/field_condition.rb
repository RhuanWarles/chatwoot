# Compares what a deal holds in a custom field with a rule ({ operator, value }). Shared by the automation
# conditions and by the routes of the "route by field" action, so both always agree on what a rule means.
class Crm::FieldCondition
  OPERATORS = %w[equals not_equals contains gt lt filled empty].freeze
  VALUELESS_OPERATORS = %w[filled empty].freeze
  ORDERED_OPERATORS = %w[gt lt].freeze
  MAX_VALUE_LENGTH = 255
  ISO_DATE = /\A\d{4}-\d{2}-\d{2}/

  def self.valid_rule?(account, custom_field_id, operator, value)
    return false unless custom_field_id.is_a?(Integer) && OPERATORS.include?(operator)
    return false unless account.crm_custom_fields.exists?(id: custom_field_id)
    return true if VALUELESS_OPERATORS.include?(operator)
    return false unless value.is_a?(String) && value.strip.present? && value.length <= MAX_VALUE_LENGTH

    !ORDERED_OPERATORS.include?(operator) || comparable?(value)
  end

  def self.met?(deal, custom_field_id, operator, expected)
    record = deal.custom_field_values.includes(:custom_field).find_by(custom_field_id: custom_field_id)
    new(operator, expected).met?(record&.typed_value)
  end

  def self.comparable?(value)
    !Float(value, exception: false).nil? || value.match?(ISO_DATE)
  end

  def initialize(operator, expected)
    @operator = operator
    @expected = expected.to_s
  end

  def met?(actual)
    case @operator
    when 'filled' then filled?(actual)
    when 'empty' then !filled?(actual)
    when 'equals' then equals?(actual)
    when 'not_equals' then !equals?(actual)
    when 'contains' then contains?(actual)
    when 'gt' then ordered(actual)&.then { |left, right| left > right } || false
    when 'lt' then ordered(actual)&.then { |left, right| left < right } || false
    else false
    end
  end

  private

  def filled?(actual)
    return false if actual.nil?
    return actual.any? if actual.is_a?(Array)

    actual.to_s.strip.present?
  end

  def equals?(actual)
    return actual.any? { |item| normalize(item) == normalize(@expected) } if actual.is_a?(Array)
    return numeric_equals?(actual) if actual.is_a?(Numeric)

    normalize(actual) == normalize(@expected)
  end

  def numeric_equals?(actual)
    number = Float(@expected, exception: false)
    !number.nil? && actual == number
  end

  def contains?(actual)
    needle = normalize(@expected)
    Array(actual).any? { |item| normalize(item).include?(needle) }
  end

  # Numbers compare numerically and ISO dates/datetimes lexicographically; anything else is not comparable.
  def ordered(actual)
    right = Float(@expected, exception: false)
    left = actual.is_a?(Numeric) ? actual : Float(actual.to_s, exception: false)
    return [left, right] if left && right
    return [actual.to_s, @expected] if actual.to_s.match?(ISO_DATE) && @expected.match?(ISO_DATE)

    nil
  end

  def normalize(value)
    value.to_s.strip.downcase
  end
end
