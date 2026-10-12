require 'cgi'
require 'json'
require 'net/http'

class Saas::AiTools::RequestBuilder
  METHODS_WITH_BODY = %w[POST PUT PATCH].freeze
  METHODS_WITH_QUERY_ARGUMENTS = %w[GET DELETE].freeze
  def initialize(tool:, account:, agent:, conversation: nil)
    @tool = tool
    @account = account
    @agent = agent
    @conversation = conversation
  end

  def build(arguments, resolved_parameters: nil)
    resolved = resolved_parameters || resolve(arguments)
    config = @tool.configuration.stringify_keys
    method = config.fetch('method').to_s.upcase
    parsed = URI.parse(render(config.fetch('url'), resolved, escape: true))
    query = config.fetch('query_params', {}).to_h.transform_values { |value| render(value, resolved) }
    query.merge!(resolved) if METHODS_WITH_QUERY_ARGUMENTS.include?(method)
    parsed.query = URI.encode_www_form(URI.decode_www_form(parsed.query.to_s) + query.to_a) if query.present?

    headers = config.fetch('headers', {}).to_h.transform_values { |value| render(value, resolved) }
    headers.merge!(JSON.parse(@tool.secret_headers)) if @tool.secret_headers.present?
    request = Net::HTTP.const_get(method.capitalize).new(parsed)
    headers.each { |name, value| request[name] = value.to_s }

    body = request_body(config, method, resolved)
    if body
      request.body = JSON.generate(body)
      request['Content-Type'] ||= 'application/json'
    end
    [request, parsed.to_s]
  end

  def resolve(arguments)
    parameters = @tool.respond_to?(:parameters) ? @tool.parameters : []
    return arguments.stringify_keys if parameters.empty?

    Saas::AiTools::ParameterResolver.new(tool: @tool, account: @account, agent: @agent, conversation: @conversation).call(arguments)
  end

  private

  def request_body(config, method, arguments)
    custom_body = config['body'].present?
    return render_object(config['body'], arguments) if custom_body && (METHODS_WITH_BODY.include?(method) || method == 'DELETE')
    return arguments if METHODS_WITH_BODY.include?(method) && !custom_body

    nil
  end

  def render(value, arguments, escape: false)
    value.to_s.gsub(/\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}/) do
      key = Regexp.last_match(1)
      source = if arguments.key?(key)
                 arguments[key]
               elsif context.key?(key)
                 context[key]
               else
                 raise CustomExceptions::SaasError, "unresolved_template_variable:#{key}"
               end
      raise CustomExceptions::SaasError, "missing_context_variable:#{key}" if source.nil?

      rendered = source.to_s
      escape ? CGI.escape(rendered) : rendered
    end
  end

  def render_object(value, arguments)
    return value.map { |item| render_object(item, arguments) } if value.is_a?(Array)
    return value.to_h.transform_values { |item| render_object(item, arguments) } if value.is_a?(Hash)

    render(value, arguments)
  end

  def context
    @context ||= Saas::AiTools::ParameterResolver.new(tool: @tool, account: @account, agent: @agent, conversation: @conversation).context
  end
end
