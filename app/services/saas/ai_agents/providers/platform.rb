class Saas::AiAgents::Providers::Platform
  def generate(model:, messages:, temperature:)
    Saas::TextService.generate_messages(messages: messages, temperature: temperature)
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed
    raise CustomExceptions::AiAgentError::Transient, 'provider_timeout_or_connection_error', cause: nil
  rescue Faraday::Error => e
    status = e.response&.dig(:status)
    raise CustomExceptions::AiAgentError::Transient, "provider_http_#{status}", cause: nil if status == 429 || (status && status >= 500)

    raise CustomExceptions::AiAgentError, "provider_http_#{status || 'unknown'}", cause: nil
  rescue RubyLLM::Error => e
    status = e.respond_to?(:response) ? e.response&.dig(:status) : nil
    transient = status == 429 || (status && status >= 500) || e.cause.is_a?(Faraday::TimeoutError) || e.cause.is_a?(Faraday::ConnectionFailed)
    raise CustomExceptions::AiAgentError::Transient, "provider_http_#{status || 'transient'}", cause: nil if transient

    raise CustomExceptions::AiAgentError, "provider_error_#{e.class.name.demodulize.underscore}", cause: nil
  rescue CustomExceptions::SaasError => e
    raise CustomExceptions::AiAgentError, e.code, cause: nil
  end
end
