class AddAttachmentInterpretationEnabledToSaasAiAgents < ActiveRecord::Migration[7.2]
  def change
    add_column :saas_ai_agents, :attachment_interpretation_enabled, :boolean, null: false, default: false
  end
end
