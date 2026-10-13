# frozen_string_literal: true

class AiAgentsConfiguration
  class << self
    def configure
      return unless installation_configs_available?

      api_key = installation_config_value('CAPTAIN_OPEN_AI_API_KEY')
      model = installation_config_value('CAPTAIN_OPEN_AI_MODEL').presence || LlmConstants::DEFAULT_MODEL
      api_endpoint = installation_config_value('CAPTAIN_OPEN_AI_ENDPOINT').presence || LlmConstants::OPENAI_API_ENDPOINT

      return unless api_key.present?

      Agents.configure do |config|
        config.openai_api_key = api_key
        config.openai_api_base = "#{api_endpoint.chomp('/')}/v1" if api_endpoint.present?
        config.default_model = model
        config.debug = false
      end
    end

    private

    def installation_configs_available?
      ActiveRecord::Base.connection.table_exists?('installation_configs')
    rescue ActiveRecord::NoDatabaseError
      false
    end

    def installation_config_value(name)
      InstallationConfig.find_by(name: name)&.value
    end
  end
end
