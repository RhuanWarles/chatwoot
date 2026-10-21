class Evolution::InstanceClient
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  def initialize(connection)
    @connection = connection
  end

  def create
    payload = request(:post, 'instance/create', body: { instanceName: @connection.instance_name, integration: 'WHATSAPP-BAILEYS', qrcode: false })
    validate_hash_payload!(payload, 'instance')
    validate_string_payload!(payload['instance']['instanceId'])
    payload
  end

  def state
    payload = request(:get, instance_path('connectionState'))
    validate_hash_payload!(payload, 'instance')
    validate_string_payload!(payload['instance']['state'])
  end

  def profile
    payload = request(:get, 'instance/fetchInstances', query: { instanceName: @connection.instance_name })
    validate_array_payload!(payload)
    payload.find { |item| item.is_a?(Hash) && item['name'] == @connection.instance_name } || raise(CustomExceptions::WhatsappConnection, :not_found)
  end

  def connect
    validate_hash_payload!(request(:get, instance_path('connect')))
  end

  def restart
    request(:post, instance_path('restart'))
  end

  def disconnect
    request(:delete, instance_path('logout'))
  end

  def delete
    request(:delete, instance_path('delete'))
  rescue CustomExceptions::WhatsappConnection => e
    raise unless e.code == 'not_found'
  end

  def configure_inbox(inbox, user)
    current = request(:get, chatwoot_path('find'))
    validate_hash_payload!(current)
    payload = { 'importContacts' => false, 'importMessages' => false }.merge(
      current.slice(*Evolution::ChatwootConfiguration::CONFIGURATION_FIELDS, 'ignoreJids')
    )
    payload['enabled'] = inbox.present?
    payload['autoCreate'] = false
    if inbox
      payload.merge!('accountId' => @connection.account_id.to_s, 'nameInbox' => inbox.name, 'url' => ENV.fetch('FRONTEND_URL'),
                     'token' => user.access_token.token, 'signMsg' => current['signMsg'] == true)
    end
    request(:post, chatwoot_path('set'), body: payload)
  end

  def webhook_url
    "#{provider_url}/#{chatwoot_path('webhook')}"
  end

  private

  def instance_path(operation)
    "instance/#{operation}/#{ERB::Util.url_encode(@connection.instance_name)}"
  end

  def chatwoot_path(operation)
    "chatwoot/#{operation}/#{ERB::Util.url_encode(@connection.instance_name)}"
  end

  def request(method, path, body: nil, query: nil)
    response = HTTParty.public_send(
      method, "#{provider_url}/#{path}",
      headers: { 'apikey' => api_key, 'Content-Type' => 'application/json', 'Accept' => 'application/json' },
      open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, follow_redirects: false, body: body&.to_json, query: query
    )
    payload = response.parsed_response
    return payload if response.success? && !(payload.is_a?(Hash) && payload['error'] == true)

    code = { 401 => :permission_denied, 403 => :permission_denied, 404 => :not_found }.fetch(response.code, :unavailable)
    raise CustomExceptions::WhatsappConnection.new(code, http_status: 502)
  rescue HTTParty::Error, SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
         Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::ETIMEDOUT, EOFError, OpenSSL::SSL::SSLError,
         URI::InvalidURIError, JSON::ParserError
    raise CustomExceptions::WhatsappConnection.new(:unavailable, http_status: 502)
  end

  def validate_hash_payload!(payload, required_key = nil)
    return payload if payload.is_a?(Hash) && (!required_key || payload[required_key].is_a?(Hash))

    raise CustomExceptions::WhatsappConnection.new(:unavailable, http_status: 502)
  end

  def validate_array_payload!(payload)
    return payload if payload.is_a?(Array)

    raise CustomExceptions::WhatsappConnection.new(:unavailable, http_status: 502)
  end

  def validate_string_payload!(payload)
    return payload if payload.is_a?(String) && payload.present?

    raise CustomExceptions::WhatsappConnection.new(:unavailable, http_status: 502)
  end

  def provider_url
    ENV['EVOLUTION_API_URL'].presence&.delete_suffix('/') || raise(CustomExceptions::WhatsappConnection.new(:unavailable, http_status: 502))
  end

  def api_key
    ENV['EVOLUTION_API_KEY'].presence || raise(CustomExceptions::WhatsappConnection.new(:unavailable, http_status: 502))
  end
end
