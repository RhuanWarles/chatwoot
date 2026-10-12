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
    sensitive_names = ai_tool.parameters.filter_map { |parameter| parameter['name'] if parameter['sensitive'] == true }
    redact_arguments(arguments, sensitive_names)
  end

  private

  def redact_arguments(value, sensitive_names, key = nil)
    return '***REDACTED***' if key.present? && sensitive_names.include?(key.to_s)
    return value.map { |item| redact_arguments(item, sensitive_names) } if value.is_a?(Array)
    return value.to_h.transform_values { |item| redact_arguments(item, sensitive_names) } if value.is_a?(Hash)

    value
  end
end
