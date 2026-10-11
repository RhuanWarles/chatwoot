class Saas::AiToolExecution < ApplicationRecord
  self.table_name = 'saas_ai_tool_executions'
  belongs_to :account
  belongs_to :ai_agent, class_name: 'Saas::AiAgent'
  belongs_to :ai_tool, class_name: 'Saas::AiTool'
  belongs_to :conversation, optional: true
end
