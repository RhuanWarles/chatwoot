# frozen_string_literal: true

require 'agents'
require Rails.root.join('lib/ai_agents_configuration')

Rails.application.config.after_initialize do
  AiAgentsConfiguration.configure
end
