class Saas::AiAgents::Providers::OpenAi
  TIMEOUT = 60
  OUTPUT_LIMIT = Saas::TextService::MAX_OUTPUT_TOKENS
  MAX_TOOL_CALLS = 5
  INVALID_ARGUMENTS = { 'success' => false, 'error' => 'invalid_arguments: the arguments must be a valid JSON object' }.freeze

  def initialize(account)
    settings = account.saas_ai_setting
    unless settings&.text_mode == 'byok' && settings.text_provider == 'openai' && settings.text_api_key.present?
      raise CustomExceptions::AiAgentError, 'account_openai_key_not_configured'
    end

    @client = OpenAI::Client.new(access_token: settings.text_api_key, request_timeout: TIMEOUT, log_errors: false)
  end

  def generate(model:, messages:, temperature:, tools: [], tool_handler: nil)
    current_messages = messages.deep_dup
    total_usage = Hash.new(0)
    tool_calls = []
    message = {}
    loop do
      parameters = { model: model, messages: current_messages, temperature: temperature, max_completion_tokens: OUTPUT_LIMIT }
      parameters[:tools] = tools if tools.present?
      parameters[:tool_choice] = 'none' if tools.present? && tool_calls.length >= MAX_TOOL_CALLS
      response = @client.chat(parameters: parameters)
      usage = response.fetch('usage', {})
      %w[prompt_tokens completion_tokens total_tokens].each { |key| total_usage[key] += usage[key].to_i }
      total_usage['cached_tokens'] += usage.dig('prompt_tokens_details', 'cached_tokens').to_i if usage.dig('prompt_tokens_details', 'cached_tokens')
      total_usage['reasoning_tokens'] += usage.dig('completion_tokens_details', 'reasoning_tokens').to_i if usage.dig('completion_tokens_details', 'reasoning_tokens')
      message = response.dig('choices', 0, 'message') || {}
      calls = Array(message['tool_calls'])
      break if calls.blank? || tool_handler.nil? || tool_calls.length >= MAX_TOOL_CALLS

      current_messages << message
      calls.each do |call|
        result = run_tool_call(call, tool_handler, tool_calls)
        current_messages << { 'role' => 'tool', 'tool_call_id' => call['id'], 'content' => tool_message_content(result) }
      end
    end
    text = message['content']
    raise CustomExceptions::AiAgentError, 'empty_response' unless text.is_a?(String) && text.strip.present?

    { content: text.strip, usage: total_usage.compact, tool_calls_count: tool_calls.length,
      tool_names: tool_calls.map { |item| item['name'] }.uniq, tool_calls: tool_calls }
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed
    raise CustomExceptions::AiAgentError::Transient, 'provider_timeout_or_connection_error', cause: nil
  rescue Faraday::Error => e
    raise_http_error(e)
  end

  private

  def run_tool_call(call, tool_handler, tool_calls)
    return { 'success' => false, 'error' => 'tool_call_limit_reached' } if tool_calls.length >= MAX_TOOL_CALLS

    name = call.dig('function', 'name').to_s
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = execute_tool(name, call.dig('function', 'arguments'), tool_handler)
    tool_calls << { 'name' => name, 'status' => result['success'] == true ? 'completed' : 'failed',
                    'duration_ms' => ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round }
    result
  end

  def execute_tool(name, raw_arguments, tool_handler)
    arguments = JSON.parse(raw_arguments.to_s)
    return INVALID_ARGUMENTS unless arguments.is_a?(Hash)

    tool_handler.call(name, arguments)
  rescue JSON::ParserError
    INVALID_ARGUMENTS
  end

  def tool_message_content(result)
    return result['result'] if result.is_a?(Hash) && result['success'] == true && result['result'].is_a?(String) && result['result'].strip.present?

    failure = result.is_a?(Hash) ? result.merge('success' => false) : { 'success' => false }
    failure['error'] = result['error'].presence if result.is_a?(Hash) && result['error'].present?
    failure['error'] ||= 'The tool did not complete successfully.'
    JSON.generate(failure)
  end

  def raise_http_error(error)
    status = error.response&.dig(:status)
    raise CustomExceptions::AiAgentError::Transient, "provider_http_#{status}", cause: nil if status == 429 || (status && status >= 500)

    raise CustomExceptions::AiAgentError, "provider_http_#{status || 'unknown'}", cause: nil
  end
end
