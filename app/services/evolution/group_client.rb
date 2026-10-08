class Evolution::GroupClient
  REQUEST_TIMEOUT = 25

  def initialize(inbox)
    @configuration = Evolution::Configuration.new(inbox)
    raise CustomExceptions::Evolution, :not_configured unless @configuration.eligible?
  end

  def get(operation, query = {})
    request(:get, operation, { query: query })
  end

  def post(operation, body)
    request(:post, operation, { body: body.to_json })
  end

  def delete(operation, query)
    request(:delete, operation, { query: query })
  end

  def instance
    records = request(:get, 'instance/fetchInstances', { query: { instanceName: @configuration.instance_name } }, scoped: false)
    records.find { |record| record['name'] == @configuration.instance_name } || raise(CustomExceptions::Evolution, :not_found)
  end

  def update_participants(group_jid, action, numbers)
    payload = post('group/updateParticipant', { groupJid: group_jid, action: action, participants: numbers })
    results = payload.fetch('updateParticipants')
    return if results.length == numbers.length && results.all? { |result| result['status'].to_s == '200' }

    code = results.any? { |result| result['status'].to_s == '403' } ? :permission_denied : :participant_rejected
    raise CustomExceptions::Evolution, code
  end

  def whatsapp_numbers(numbers)
    payload = post('chat/whatsappNumbers', { numbers: numbers })
    records = payload.is_a?(Array) ? payload : payload.fetch('numbers')
    unless records.length == numbers.length && records.all? { |record| record['exists'] == true }
      raise CustomExceptions::Evolution, :not_on_whatsapp
    end

    records.each_with_index.map do |record, index|
      jid = record['jid'].to_s
      jid.match?(/\A\d+@s\.whatsapp\.net\z/) ? jid.delete_suffix('@s.whatsapp.net') : numbers[index]
    end.uniq
  end

  private

  def request(method, operation, options, scoped: true)
    path = scoped ? "#{operation}/#{ERB::Util.url_encode(@configuration.instance_name)}" : operation
    response = HTTParty.public_send(
      method, "#{@configuration.base_url}/#{path}",
      headers: { 'apikey' => @configuration.api_key, 'Content-Type' => 'application/json', 'Accept' => 'application/json' },
      timeout: REQUEST_TIMEOUT, **options
    )
    unless response.success?
      Rails.logger.warn("[Evolution] #{operation} failed: HTTP #{response.code}")
      code = { 401 => :permission_denied, 403 => :permission_denied, 404 => :not_found }.fetch(response.code, :unavailable)
      raise CustomExceptions::Evolution.new(code, uncertain: response.code >= 500)
    end
    response.parsed_response
  rescue HTTParty::Error, SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, JSON::ParserError => e
    Rails.logger.warn("[Evolution] #{operation} unavailable: #{e.class}")
    raise CustomExceptions::Evolution.new(:unavailable, http_status: 502, uncertain: true)
  end
end
