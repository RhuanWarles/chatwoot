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
    return unless digits.match?(/\A[1-9]\d{#{minimum_digits - 1},14}\z/)

    normalize_brazilian_mobile(digits)
  end

  def self.normalize_brazilian_mobile(digits)
    return digits unless digits.start_with?('55')

    national = digits.delete_prefix('55')
    return digits unless national.length == 10 && national.match?(/\A[1-9]\d{7}\z/)

    "55#{national[0, 2]}9#{national[2, 8]}"
  end
  private_class_method :normalize_brazilian_mobile
end
