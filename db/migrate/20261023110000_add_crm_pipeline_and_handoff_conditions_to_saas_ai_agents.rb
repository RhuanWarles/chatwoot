class AddCrmPipelineAndHandoffConditionsToSaasAiAgents < ActiveRecord::Migration[7.2]
  def change
    add_column :saas_ai_agents, :crm_pipeline_id, :bigint
    add_column :saas_ai_agents, :handoff_conditions, :text
    add_index :saas_ai_agents, :crm_pipeline_id
  end
end
