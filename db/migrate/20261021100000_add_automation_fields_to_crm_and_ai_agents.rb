class AddAutomationFieldsToCrmAndAiAgents < ActiveRecord::Migration[7.2]
  def change
    add_column :crm_pipeline_stages, :automations, :jsonb, null: false, default: []
    add_column :crm_pipeline_stages, :ai_instructions, :text
    add_column :saas_ai_agents, :crm_stage_automation_enabled, :boolean, null: false, default: false
  end
end
