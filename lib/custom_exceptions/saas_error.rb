class CustomExceptions::SaasError < StandardError
  attr_reader :code

  def initialize(code)
    @code = code
    super(code)
  end
end
