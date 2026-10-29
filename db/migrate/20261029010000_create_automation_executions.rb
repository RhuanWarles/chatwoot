class CreateAutomationExecutions < ActiveRecord::Migration[7.0]
  def change
    create_table :automation_executions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :automation_rule, null: false, foreign_key: true
      t.references :conversation, foreign_key: true
      t.references :contact, foreign_key: true
      t.references :crm_deal, foreign_key: { to_table: :crm_deals }
      t.string :action_name, null: false
      t.string :trigger, null: false
      t.string :status, null: false, default: 'started'
      t.string :idempotency_key
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.timestamps
    end

    add_index :automation_executions, :idempotency_key, unique: true
    add_index :automation_executions, [:automation_rule_id, :conversation_id, :created_at], name: 'idx_automation_executions_rule_conversation'
  end
end
