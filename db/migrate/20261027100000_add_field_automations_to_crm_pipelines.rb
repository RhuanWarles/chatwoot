class AddFieldAutomationsToCrmPipelines < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_pipelines, :field_automations, :jsonb, null: false, default: []
  end
end
