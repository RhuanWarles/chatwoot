class Saas::AiToolAgent < ApplicationRecord
  self.table_name = 'saas_ai_tool_agents'

  belongs_to :account
  belongs_to :ai_tool, class_name: 'Saas::AiTool'
  belongs_to :ai_agent, class_name: 'Saas::AiAgent'
  validate :same_account

  private

  def same_account
    errors.add(:base, :invalid) if ai_tool && ai_agent && (ai_tool.account_id != account_id || ai_agent.account_id != account_id)
  end
end
