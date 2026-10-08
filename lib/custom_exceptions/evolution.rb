class CustomExceptions::Evolution < StandardError
  attr_reader :code, :http_status, :uncertain

  def initialize(code, http_status: 422, uncertain: false)
    @code = code.to_s
    @http_status = http_status
    @uncertain = uncertain
    super(I18n.t("evolution_groups.errors.#{code}"))
  end
end
