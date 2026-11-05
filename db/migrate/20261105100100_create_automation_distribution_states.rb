class CreateAutomationDistributionStates < ActiveRecord::Migration[7.1]
  def change
    # The running score of a weighted round robin, one row per workflow step.
    create_table :automation_distribution_states do |t|
      t.bigint :account_id, null: false
      t.bigint :automation_workflow_id, null: false
      t.string :node_id, null: false
      t.string :signature, null: false
      t.jsonb :scores, null: false, default: {}
      t.timestamps
    end
    add_index :automation_distribution_states, :account_id
    add_index :automation_distribution_states, [:automation_workflow_id, :node_id], unique: true, name: 'idx_automation_distribution_workflow_node'
  end
end
