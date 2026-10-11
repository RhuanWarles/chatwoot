require 'ipaddr'
require 'cgi'
require 'net/http'
require 'resolv'
require 'securerandom'

class Saas::AiTools::Executor
  MAX_RESPONSE_BYTES = 20_000
  RESERVED_HOSTS = %w[localhost metadata metadata.google.internal].freeze

  def initialize(account:, agent:, conversation: nil, playground_session_id: nil)
    @account = account
    @agent = agent
    @conversation = conversation
    @playground_session_id = playground_session_id
  end

  def call(tool_name, arguments)
    tool = @agent.tools.find_by(account_id: @account.id, slug: tool_name)
    return failure('tool_not_available') unless tool&.active?

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    request_id = SecureRandom.uuid
    args = arguments.is_a?(Hash) ? arguments.stringify_keys : {}
    validation = validate_arguments(tool, args)
    return record_failure(tool, request_id, validation, started) unless validation == true

    uri = rendered_uri(tool, args)
    validate_uri!(uri)
    request = build_request(tool, uri, args)
    response = perform_request(request, uri, tool.configuration['timeout_seconds'].to_i)
    normalized = normalize_response(response)
    status = response.code.to_i.between?(200, 299) ? 'completed' : 'failed'
    persist_execution(tool, request_id, masked_arguments(tool, args), status, response.code.to_i, started, status == 'failed' ? 'tool_http_error' : nil)
    Rails.logger.info({ event: 'saas_ai_tool', account_id: @account.id, ai_agent_id: @agent.id, conversation_id: @conversation&.id,
                        ai_tool_id: tool.id, tool_name: tool.slug, execution_id: request_id, status: status,
                        duration_ms: elapsed_ms(started) }.compact.to_json)
    { 'success' => status == 'completed', 'status' => response.code.to_i, 'duration_ms' => elapsed_ms(started), 'data' => normalized }
  rescue URI::InvalidURIError, CustomExceptions::SaasError => error
    record_failure(tool, request_id || SecureRandom.uuid, error.respond_to?(:code) ? error.code : 'invalid_tool_request', started)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    record_failure(tool, request_id || SecureRandom.uuid, 'tool_timeout_or_connection_error', started)
  rescue StandardError => error
    Rails.logger.warn({ event: 'saas_ai_tool', status: 'error', ai_tool_id: tool&.id, error: error.class.name }.to_json)
    record_failure(tool, request_id || SecureRandom.uuid, 'tool_request_failed', started)
  end

  private

  def validate_arguments(tool, arguments)
    parameters = tool.parameters
    names = parameters.map { |item| item['name'] }
    return 'unknown_argument' unless (arguments.keys - names).empty?
    return 'missing_required_argument' unless parameters.select { |item| item['required'] == true }.all? { |item| arguments.key?(item['name']) }

    parameters.each do |parameter|
      next unless arguments.key?(parameter['name'])

      value = arguments[parameter['name']]
      valid = case parameter['type']
              when 'string', 'enum' then value.is_a?(String)
              when 'number' then value.is_a?(Numeric)
              when 'integer' then value.is_a?(Integer)
              when 'boolean' then value == true || value == false
              end
      valid &&= Array(parameter['enum_values']).map(&:to_s).include?(value.to_s) if parameter['type'] == 'enum'
      return 'invalid_argument' unless valid
    end
    true
  end

  def rendered_uri(tool, args)
    render(tool.configuration.fetch('url'), args, escape: true)
  end

  def render(value, args, escape: false)
    internals = { 'account_id' => @account.id, 'conversation_id' => @conversation&.id, 'contact_id' => @conversation&.contact_id, 'agent_id' => @agent.id }
    value.to_s.gsub(/\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}/) do
      key = Regexp.last_match(1)
      raise CustomExceptions::SaasError, 'invalid_template_variable' unless args.key?(key) || internals.key?(key)

      rendered = (args[key] || internals[key]).to_s
      escape ? CGI.escape(rendered) : rendered
    end
  end

  def validate_uri!(uri)
    parsed = URI.parse(uri)
    raise CustomExceptions::SaasError, 'invalid_tool_url' unless parsed.is_a?(URI::HTTP) && parsed.userinfo.nil? && parsed.host.present?
    host = parsed.hostname.downcase
    raise CustomExceptions::SaasError, 'ssrf_blocked' if RESERVED_HOSTS.include?(host) || host.end_with?('.local')
    addresses = Resolv.getaddresses(host)
    raise CustomExceptions::SaasError, 'ssrf_blocked' if addresses.empty? || addresses.any? { |address| private_address?(address) }
  end

  def private_address?(address)
    ip = IPAddr.new(address)
    ip.loopback? || ip.private? || ip.link_local? || ip.zero? || ip.to_s == '169.254.169.254'
  rescue IPAddr::InvalidAddressError
    true
  end

  def build_request(tool, uri, args)
    parsed = URI.parse(uri)
    query = tool.configuration.fetch('query_params', {}).to_h.transform_values { |value| render(value, args) }
    parsed.query = URI.encode_www_form((URI.decode_www_form(parsed.query.to_s) + query.to_a)) if query.present?
    headers = tool.configuration.fetch('headers', {}).to_h.transform_values { |value| render(value, args) }
    headers.merge!(JSON.parse(tool.secret_headers)) if tool.secret_headers.present?
    klass = Net::HTTP.const_get(tool.configuration.fetch('method').to_s.capitalize)
    request = klass.new(parsed)
    headers.each { |name, value| request[name] = value.to_s }
    body = tool.configuration['body']
    request.body = JSON.generate(render_object(body, args)) if body.present? && !request.is_a?(Net::HTTP::Get) && !request.is_a?(Net::HTTP::Delete)
    request['Content-Type'] ||= 'application/json' if request.body
    request
  end

  def render_object(value, args)
    return value.map { |item| render_object(item, args) } if value.is_a?(Array)
    return value.to_h.transform_values { |item| render_object(item, args) } if value.is_a?(Hash)

    render(value, args)
  end

  def perform_request(request, uri, timeout)
    parsed = URI.parse(uri)
    http = Net::HTTP.new(parsed.host, parsed.port)
    http.use_ssl = parsed.scheme == 'https'
    http.open_timeout = timeout
    http.read_timeout = timeout
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
    http.request(request)
  end

  def normalize_response(response)
    body = response.body.to_s.byteslice(0, MAX_RESPONSE_BYTES)
    return { 'truncated' => true, 'content_type' => response['content-type'] } if response['content-type'].to_s.match?(/image|audio|video|octet-stream/i)
    JSON.parse(body)
  rescue JSON::ParserError
    { 'text' => body, 'truncated' => response.body.to_s.bytesize > MAX_RESPONSE_BYTES }
  end

  def masked_arguments(tool, args)
    sensitive = tool.parameters.select { |item| item['sensitive'] == true }.map { |item| item['name'] }
    args.merge(args.slice(*sensitive).transform_values { '***' })
  end

  def persist_execution(tool, request_id, args, status, response_status, started, error_code)
    Saas::AiToolExecution.create!(account: @account, ai_agent: @agent, ai_tool: tool, conversation: @conversation,
                                  playground_session_id: @playground_session_id, request_id: request_id, arguments: args,
                                  status: status, response_status: response_status, duration_ms: elapsed_ms(started), error_code: error_code)
  end

  def record_failure(tool, request_id, error_code, started)
    persist_execution(tool, request_id, {}, 'failed', nil, started, error_code) if tool
    { 'success' => false, 'error' => error_code.to_s, 'status' => nil, 'duration_ms' => elapsed_ms(started) }
  end

  def failure(code)
    { 'success' => false, 'error' => code, 'status' => nil }
  end

  def elapsed_ms(started)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  end
end
