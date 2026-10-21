class Evolution::ChatwootConfiguration
  REQUEST_TIMEOUT = 15
  HTTP_ERROR_CODES = {
    401 => :permission_denied,
    403 => :permission_denied,
    404 => :not_found,
    408 => :timeout,
    504 => :timeout
  }.freeze
  CONFIGURATION_FIELDS = %w[
    enabled accountId token url signMsg signDelimiter nameInbox reopenConversation conversationPending
    mergeBrazilContacts importContacts importMessages daysLimitImportMessages organization logo
  ].freeze

  def initialize(inbox)
    @configuration = Evolution::Configuration.new(inbox)
    raise CustomExceptions::Evolution, :not_configured unless @configuration.eligible?
  end

  def show
    normalize(configuration_payload(request(:get, 'find'), 'find'))
  end

  def update_sign_msg(sign_msg)
    current = configuration_payload(request(:get, 'find'), 'find')
    payload = current.deep_dup
    payload['signMsg'] = sign_msg

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

    with_request_errors(operation) do
      response = HTTParty.public_send(method, "#{@configuration.base_url}/#{path}", **options)
      response.success? ? response.parsed_response : raise_provider_error(operation, response)
    end
  end

  def with_request_errors(operation)
    yield
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise_request_error(operation, e, :timeout, 504, uncertain: true)
  rescue JSON::ParserError => e
    raise_request_error(operation, e, :invalid_payload, 502)
  rescue HTTParty::Error, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
         Errno::ENETUNREACH, EOFError, OpenSSL::SSL::SSLError, URI::InvalidURIError => e
    raise_request_error(operation, e, :unavailable, 502, uncertain: true)
  end

  def configuration_payload(payload, operation)
    return payload if payload.is_a?(Hash)

    Rails.logger.warn("[Evolution] chatwoot/#{operation} invalid payload instance=#{@configuration.instance_name} type=#{payload.class.name}")
    raise CustomExceptions::Evolution.new(:invalid_payload, http_status: 502)
  end

  def raise_provider_error(operation, response)
    status = response.code.to_i
    log_provider_error(operation, response, status)
    code = HTTP_ERROR_CODES.fetch(status, :provider_error)
    code = :provider_error if status.between?(500, 599)
    raise CustomExceptions::Evolution.new(
      code,
      http_status: http_status_for(code, status),
      uncertain: uncertain_status?(code, status)
    )
  end

  def raise_request_error(operation, error, code, http_status, uncertain: false)
    log_request_error(operation, error)
    raise CustomExceptions::Evolution.new(code, http_status: http_status, uncertain: uncertain)
  end

  def http_status_for(code, status)
    return 504 if code == :timeout
    return 502 if status.between?(500, 599)

    422
  end

  def uncertain_status?(code, status)
    code == :timeout || status.between?(500, 599)
  end

  def log_provider_error(operation, response, status)
    body = begin
      redact_payload(response.parsed_response).to_json
    rescue JSON::ParserError
      '[invalid-json]'
    end
    Rails.logger.warn("[Evolution] chatwoot/#{operation} failed instance=#{@configuration.instance_name} status=#{status} body=#{body}")
  end

  def log_request_error(operation, error)
    Rails.logger.warn("[Evolution] chatwoot/#{operation} failed instance=#{@configuration.instance_name} error=#{error.class}: #{error.message}")
  end

  def redact_payload(payload)
    case payload
    when Hash
      payload.each_with_object({}) do |(key, value), redacted|
        redacted[key] = key.to_s.match?(/token|key|secret|password|authorization/i) ? '[REDACTED]' : redact_payload(value)
      end
    when Array
      payload.map { |value| redact_payload(value) }
    else
      payload
    end
  end
end
