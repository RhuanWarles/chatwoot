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

  def generate(model:, messages:, temperature:)
    response = @client.chat(parameters: {
                              model: model, messages: messages, temperature: temperature,
                              max_completion_tokens: OUTPUT_LIMIT
                            })
    text = response.dig('choices', 0, 'message', 'content')
    raise CustomExceptions::AiAgentError, 'empty_response' unless text.is_a?(String) && text.strip.present?

    { content: text.strip, usage: response.fetch('usage', {}).slice('prompt_tokens', 'completion_tokens', 'total_tokens') }
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
