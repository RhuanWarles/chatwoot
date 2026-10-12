class Saas::AiAgents::Providers::OpenAi
  TIMEOUT = 60
  OUTPUT_LIMIT = Saas::TextService::MAX_OUTPUT_TOKENS

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
    tool_names = []
    tool_calls_count = 0
    message = {}
    loop do
      parameters = { model: model, messages: current_messages, temperature: temperature, max_completion_tokens: OUTPUT_LIMIT }
      parameters[:tools] = tools if tools.present?
      response = @client.chat(parameters: parameters)
      usage = response.fetch('usage', {})
      %w[prompt_tokens completion_tokens total_tokens].each { |key| total_usage[key] += usage[key].to_i }
      total_usage['cached_tokens'] += usage.dig('prompt_tokens_details', 'cached_tokens').to_i if usage.dig('prompt_tokens_details', 'cached_tokens')
      total_usage['reasoning_tokens'] += usage.dig('completion_tokens_details', 'reasoning_tokens').to_i if usage.dig('completion_tokens_details', 'reasoning_tokens')
      message = response.dig('choices', 0, 'message') || {}
      calls = Array(message['tool_calls'])
      break unless calls.present? && tool_handler
      current_messages << message
      calls.each do |call|
        tool_calls_count += 1
        raise CustomExceptions::AiAgentError, 'tool_call_limit' if tool_calls_count > 5
        name = call.dig('function', 'name').to_s
        tool_names << name
        args = JSON.parse(call.dig('function', 'arguments').to_s)
        result = tool_handler.call(name, args)
        current_messages << { 'role' => 'tool', 'tool_call_id' => call['id'], 'content' => JSON.generate(result) }
      end
    end
    text = message['content']
    raise CustomExceptions::AiAgentError, 'empty_response' unless text.is_a?(String) && text.strip.present?

    { content: text.strip, usage: total_usage.compact, tool_calls_count: tool_calls_count, tool_names: tool_names.uniq }
  rescue JSON::ParserError
    raise CustomExceptions::AiAgentError, 'invalid_tool_arguments'
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed
    raise CustomExceptions::AiAgentError::Transient, 'provider_timeout_or_connection_error', cause: nil
  rescue Faraday::Error => e
    raise_http_error(e)
  end

  private

  def raise_http_error(error)
    status = error.response&.dig(:status)
    raise CustomExceptions::AiAgentError::Transient, "provider_http_#{status}", cause: nil if status == 429 || (status && status >= 500)

    raise CustomExceptions::AiAgentError, "provider_http_#{status || 'unknown'}", cause: nil
  end
end
