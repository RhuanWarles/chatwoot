class AddOutcomeAutomationsToCrmPipelines < ActiveRecord::Migration[7.2]
  def change
    add_column :crm_pipelines, :won_automations, :jsonb, null: false, default: []
    add_column :crm_pipelines, :lost_automations, :jsonb, null: false, default: []
  end
end
