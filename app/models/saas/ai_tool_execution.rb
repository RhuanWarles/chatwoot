class Saas::AiToolExecution < ApplicationRecord
  self.table_name = 'saas_ai_tool_executions'
  belongs_to :account
  belongs_to :ai_agent, class_name: 'Saas::AiAgent'
  belongs_to :ai_tool, class_name: 'Saas::AiTool'
  belongs_to :conversation, optional: true

  def source
    return 'test' if playground_session_id.to_s.start_with?('test:')
    return 'playground' if playground_session_id.present?
    return 'conversation' if conversation_id.present?

    'unknown'
  end

  def safe_arguments
    sensitive_names = ai_tool.parameters.filter_map { |parameter| parameter['name'].downcase if parameter['sensitive'] == true }
    sensitive_names += %w[authorization apikey api_key x-api-key cookie cookies credentials password secret token]
    redact_arguments(arguments, sensitive_names)
  end

  private

  def redact_arguments(value, sensitive_names, key = nil)
    return '***REDACTED***' if key.present? && sensitive_names.include?(key.to_s.downcase)
    return value.map { |item| redact_arguments(item, sensitive_names) } if value.is_a?(Array)
    if value.is_a?(Hash)
      return value.each_with_object({}) do |(name, item), result|
        result[name.to_s] = redact_arguments(item, sensitive_names, name)
      end
    end

    value
  end
end
