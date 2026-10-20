class Evolution::InstanceClient
  REQUEST_TIMEOUT = 15

  def initialize(connection)
    @connection = connection
  end

  def create
    request(:post, 'instance/create', body: { instanceName: @connection.instance_name, integration: 'WHATSAPP-BAILEYS', qrcode: false })
  end

  def state
    request(:get, instance_path('connectionState')).fetch('instance').fetch('state')
  end

  def profile
    request(:get, 'instance/fetchInstances', query: { instanceName: @connection.instance_name })
      .find { |item| item['name'] == @connection.instance_name } || raise(CustomExceptions::WhatsappConnection, :not_found)
  end

  def connect
    request(:get, instance_path('connect'))
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
    "#{ENV.fetch('EVOLUTION_API_URL').delete_suffix('/')}/#{chatwoot_path('webhook')}"
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
      method, "#{ENV.fetch('EVOLUTION_API_URL').delete_suffix('/')}/#{path}",
      headers: { 'apikey' => ENV.fetch('EVOLUTION_API_KEY'), 'Content-Type' => 'application/json', 'Accept' => 'application/json' },
      timeout: REQUEST_TIMEOUT, follow_redirects: false, body: body&.to_json, query: query
    )
    payload = response.parsed_response
    return payload if response.success? && !(payload.is_a?(Hash) && payload['error'] == true)

    code = { 401 => :permission_denied, 403 => :permission_denied, 404 => :not_found }.fetch(response.code, :unavailable)
    raise CustomExceptions::WhatsappConnection.new(code, http_status: 502)
  rescue HTTParty::Error, SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
         OpenSSL::SSL::SSLError, JSON::ParserError
    raise CustomExceptions::WhatsappConnection.new(:unavailable, http_status: 502)
  end
end
