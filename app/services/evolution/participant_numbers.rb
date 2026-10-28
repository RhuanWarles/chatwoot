class Evolution::ParticipantNumbers
  def self.normalize(numbers)
    raise CustomExceptions::Evolution, :invalid_phone unless numbers.is_a?(Array) && numbers.present?

    numbers.map do |number|
      digits = normalize_phone(number)
      raise CustomExceptions::Evolution, :invalid_phone unless digits

      digits
    end.uniq
  end

  def self.normalize_phone(number, minimum_digits: 10)
    return unless number.is_a?(String) && number.match?(/\A\+?[\d\s().-]+\z/)

    digits = number.gsub(/\D/, '')
    digits if digits.match?(/\A[1-9]\d{#{minimum_digits - 1},14}\z/)
  end
end
