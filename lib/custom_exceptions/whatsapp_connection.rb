class CustomExceptions::WhatsappConnection < StandardError
  attr_reader :code, :http_status

  def initialize(code, http_status: 422)
    @code = code.to_s
    @http_status = http_status
    super(I18n.t("whatsapp_connections.errors.#{code}"))
  end
end
