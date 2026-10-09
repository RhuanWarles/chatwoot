class Saas::AiAgents::Provider
  def self.for(account, provider)
    raise CustomExceptions::AiAgentError, 'unsupported_provider' unless provider == 'openai'

    Saas::AiAgents::Providers::OpenAi.new(account)
  end
end
