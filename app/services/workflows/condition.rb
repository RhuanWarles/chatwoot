class Workflows::Condition
  OPERATORS = %w[equals not_equals contains not_contains starts_with ends_with gt gte lt lte is_present is_blank in not_in].freeze
  COMPARISONS = { 'gt' => :>, 'gte' => :>=, 'lt' => :<, 'lte' => :<= }.freeze

  class << self
    def met?(actual, operator, expected)
      case operator
      when 'is_present' then actual.present?
      when 'is_blank' then actual.blank?
      when 'equals' then same?(actual, expected)
      when 'not_equals' then !same?(actual, expected)
      when 'in' then Array(expected).any? { |item| same?(actual, item) }
      when 'not_in' then Array(expected).none? { |item| same?(actual, item) }
      when 'contains' then contains?(actual, expected)
      when 'not_contains' then !contains?(actual, expected)
      when 'starts_with' then actual.to_s.downcase.start_with?(expected.to_s.downcase)
      when 'ends_with' then actual.to_s.downcase.end_with?(expected.to_s.downcase)
      when *COMPARISONS.keys then compare(actual, expected, COMPARISONS.fetch(operator))
      else false
      end
    end

    private

    # Lists (labels) match when they hold the value; numbers match numerically ("1500" == 1500.0); text ignores case.
    def same?(actual, expected)
      return actual.any? { |item| same?(item, expected) } if actual.is_a?(Array)

      numbers = [number(actual), number(expected)]
      return numbers.first == numbers.last if numbers.none?(&:nil?)

      actual.to_s.casecmp?(expected.to_s)
    end

    def contains?(actual, expected)
      return same?(actual, expected) if actual.is_a?(Array)

      actual.to_s.downcase.include?(expected.to_s.downcase)
    end

    def compare(actual, expected, operator)
      left = number(actual)
      right = number(expected)
      return false if left.nil? || right.nil?

      left.public_send(operator, right)
    end

    def number(value)
      Float(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
