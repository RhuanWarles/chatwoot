module CrmGoogleCalendarConcern
  extend ActiveSupport::Concern
  include GoogleConcern
  HTTP_TIMEOUT = 20
  HTTP_OPEN_TIMEOUT = 5

  def google_client
    @google_client ||= super.tap do |client|
      client.options[:auth_scheme] = :request_body
      client.connection.options.timeout = HTTP_TIMEOUT
      client.connection.options.open_timeout = HTTP_OPEN_TIMEOUT
    end
  end
end
