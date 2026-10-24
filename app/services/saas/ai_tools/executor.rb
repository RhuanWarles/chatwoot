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
    return failure('tool_not_available') unless tool

    perform(tool, arguments, ignore_inactive: false)
  end

  # Ignores the active flag and the agent attachment, but is still logged like any other execution.
  def test(tool, arguments)
    perform(tool, arguments, ignore_inactive: true)
  end

  private

  def perform(tool, arguments, ignore_inactive:)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    request_id = SecureRandom.uuid
    return record_failure(tool, request_id, 'tool_not_available', started) if !tool.active? && !ignore_inactive

    args = arguments.is_a?(Hash) ? arguments.stringify_keys.compact : {}
    validation = validate_arguments(tool, args)
    return record_failure(tool, request_id, validation, started) unless validation == true

    request_builder = Saas::AiTools::RequestBuilder.new(tool: tool, account: @account, agent: @agent, conversation: @conversation)
    resolved = request_builder.resolve(args)
    request, uri = request_builder.build(args, resolved_parameters: resolved)
    validate_uri!(uri)
    response = perform_request(request, uri, tool.configuration['timeout_seconds'].to_i)
    normalized = normalize_response(response)
    status = normalized[:valid] ? 'completed' : 'failed'
    error_code = normalized[:valid] ? nil : normalized[:error_code]
    persist_execution(tool, request_id, masked_arguments(tool, resolved), status, response.code.to_i, started, error_code)
    Rails.logger.info({ event: 'saas_ai_tool', account_id: @account.id, ai_agent_id: @agent.id, conversation_id: @conversation&.id,
                        ai_tool_id: tool.id, tool_name: tool.slug, execution_id: request_id, status: status,
                        response_contract_valid: normalized[:valid], tool_result_preview: normalized[:result].to_s.byteslice(0, 200),
                        error_code: error_code, duration_ms: elapsed_ms(started) }.compact.to_json)
    { 'success' => normalized[:valid], 'status' => response.code.to_i, 'http_status' => response.code.to_i, 'duration_ms' => elapsed_ms(started),
      'response_contract_valid' => normalized[:valid], 'result' => normalized[:result], 'error_code' => error_code,
      'error' => normalized[:error] }.compact
  rescue URI::InvalidURIError, CustomExceptions::SaasError => error
    record_failure(tool, request_id, error.respond_to?(:code) ? error.code : 'invalid_tool_request', started)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    record_failure(tool, request_id, 'tool_timeout_or_connection_error', started)
  rescue StandardError => error
    Rails.logger.warn({ event: 'saas_ai_tool', status: 'error', ai_tool_id: tool.id, error: error.class.name }.to_json)
    record_failure(tool, request_id, 'tool_request_failed', started)
  end

  def validate_arguments(tool, arguments)
    parameters = tool.parameters.select { |item| item['value_source'].to_s.presence.in?([nil, 'ai']) }
    names = parameters.map { |item| item['name'] }
    unknown = arguments.keys - names
    return "unknown_argument:#{unknown.first.to_s.first(64)}" if unknown.any?

    missing = parameters.find { |item| item['required'] == true && !arguments.key?(item['name']) }
    return "missing_required_argument:#{missing['name']}" if missing

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
      return "invalid_argument:#{parameter['name']}" unless valid
    end
    true
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
    ip.loopback? || ip.private? || ip.link_local? || ip.to_i.zero? || ip.to_s == '169.254.169.254'
  rescue IPAddr::InvalidAddressError
    true
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
    return failure_response(response, 'invalid_tool_response', 'The tool response must be valid JSON.') unless response.code.to_i.between?(200, 299)

    parsed = JSON.parse(body)
    return failure_response(response, 'invalid_tool_response', 'The tool response must be a JSON object.') unless parsed.is_a?(Hash)
    return failure_response(response, 'success_field_missing', 'The tool response is missing the success field.') unless parsed.key?('success')
    return failure_response(response, 'success_false', parsed['error'].presence || parsed['result'].presence || 'The tool reported failure.') unless parsed['success'] == true
    return failure_response(response, 'result_field_missing', 'The tool response is missing the result field.') unless parsed.key?('result')
    return failure_response(response, 'result_invalid', 'The tool result must be a non-empty string.') unless parsed['result'].is_a?(String) && parsed['result'].strip.present?

    { valid: true, result: parsed['result'] }
  rescue JSON::ParserError
    failure_response(response, 'invalid_tool_response', 'The tool response must be valid JSON.')
  rescue StandardError
    failure_response(response, 'invalid_tool_response', 'The tool response could not be validated.')
  end

  def failure_response(response, error_code, error)
    return { valid: false, error_code: error_code, error: error } if response.code.to_i.between?(200, 299)

    body = response.body.to_s.byteslice(0, MAX_RESPONSE_BYTES)
    message = begin
      parsed = JSON.parse(body)
      parsed.is_a?(Hash) ? parsed['error'].to_s.presence : nil
    rescue JSON::ParserError
      nil
    end
    { valid: false, error_code: 'http_error', error: message || "Tool request failed with HTTP #{response.code.to_i}." }
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
    persist_execution(tool, request_id, {}, 'failed', nil, started, error_code)
    Rails.logger.warn({ event: 'saas_ai_tool', account_id: @account.id, ai_agent_id: @agent.id,
                        conversation_id: @conversation&.id, ai_tool_id: tool.id, status: 'failed',
                        error_code: error_code, execution_id: request_id, duration_ms: elapsed_ms(started) }.compact.to_json)
    { 'success' => false, 'error' => error_code.to_s, 'status' => nil, 'duration_ms' => elapsed_ms(started) }
  end

  def failure(code)
    { 'success' => false, 'error' => code, 'status' => nil }
  end

  def elapsed_ms(started)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  end
end
