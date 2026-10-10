class Evolution::ChatwootConfiguration
  REQUEST_TIMEOUT = 15
  CONFIGURATION_FIELDS = %w[
    enabled accountId token url signMsg signDelimiter nameInbox reopenConversation conversationPending
    mergeBrazilContacts importContacts importMessages daysLimitImportMessages organization logo
  ].freeze

  def initialize(inbox)
    @configuration = Evolution::Configuration.new(inbox)
    raise CustomExceptions::Evolution, :not_configured unless @configuration.eligible?
  end

  def show
    normalize(request(:get, 'find'))
  end

  def update_sign_msg(sign_msg)
    current = request(:get, 'find')
    payload = current.slice(*CONFIGURATION_FIELDS)
    payload['signMsg'] = sign_msg
    payload['signDelimiter'] = nil unless sign_msg

    request(:post, 'set', payload)
    show
  end

  private

  def normalize(payload)
    {
      instance_name: @configuration.instance_name,
      configured: payload['enabled'] == true,
      sign_msg: payload['signMsg'] == true
    }
  end

  def request(method, operation, body = nil)
    path = "chatwoot/#{operation}/#{ERB::Util.url_encode(@configuration.instance_name)}"
    options = {
      headers: {
        'apikey' => @configuration.api_key,
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      },
      timeout: REQUEST_TIMEOUT
    }
    options[:body] = body.to_json if body

    response = HTTParty.public_send(method, "#{@configuration.base_url}/#{path}", **options)
    return response.parsed_response if response.success?

    Rails.logger.warn("[Evolution] chatwoot/#{operation} failed: HTTP #{response.code}")
    code = { 401 => :permission_denied, 403 => :permission_denied, 404 => :not_found }.fetch(response.code, :unavailable)
    raise CustomExceptions::Evolution.new(code, http_status: response.code >= 500 ? 502 : 422, uncertain: response.code >= 500)
  rescue HTTParty::Error, SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
         JSON::ParserError => e
    Rails.logger.warn("[Evolution] chatwoot/#{operation} unavailable: #{e.class}")
    raise CustomExceptions::Evolution.new(:unavailable, http_status: 502, uncertain: true)
  end
end
