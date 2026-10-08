class Evolution::ParticipantNumbers
  def self.normalize(numbers)
    raise CustomExceptions::Evolution, :invalid_phone unless numbers.is_a?(Array) && numbers.present?

    numbers.map do |number|
      unless number.is_a?(String) && number.match?(/\A\+?[\d\s().-]+\z/)
        raise CustomExceptions::Evolution, :invalid_phone
      end

      digits = number.gsub(/\D/, '')
      raise CustomExceptions::Evolution, :invalid_phone unless digits.match?(/\A[1-9]\d{9,14}\z/)

      digits
    end.uniq
  end
end
