class Saas::AiAgents::Provider
  TOOL_PROVIDERS = %w[openai].freeze

  def self.for(account, provider, mode: account.saas_ai_setting&.text_mode || 'platform')
    return Saas::AiAgents::Providers::Platform.new if mode == 'platform'
    raise CustomExceptions::AiAgentError, 'unsupported_provider' unless provider == 'openai'

    Saas::AiAgents::Providers::OpenAi.new(account)
  end

  def self.tools_supported?(provider)
    TOOL_PROVIDERS.include?(provider)
  end
end
