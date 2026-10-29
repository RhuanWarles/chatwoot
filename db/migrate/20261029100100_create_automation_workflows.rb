class CreateAutomationWorkflows < ActiveRecord::Migration[7.1]
  def change
    create_table :automation_workflows do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: false
      t.jsonb :graph, null: false, default: { nodes: [], edges: [] }
      t.string :trigger_events, array: true, null: false, default: []
      t.string :webhook_token, null: false
      t.timestamps
    end
    add_index :automation_workflows, :account_id
    add_index :automation_workflows, :webhook_token, unique: true
    add_index :automation_workflows, :trigger_events, using: :gin

    create_table :automation_workflow_runs do |t|
      t.bigint :account_id, null: false
      t.bigint :automation_workflow_id, null: false
      t.string :status, null: false, default: 'running'
      t.string :trigger_event, null: false
      t.jsonb :context, null: false, default: {}
      t.jsonb :pending, null: false, default: []
      t.jsonb :trace, null: false, default: []
      t.text :error
      t.datetime :resume_at
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end
    add_index :automation_workflow_runs, [:automation_workflow_id, :created_at], name: 'idx_automation_workflow_runs_on_workflow'
    add_index :automation_workflow_runs, [:status, :resume_at], name: 'idx_automation_workflow_runs_on_due'
    add_index :automation_workflow_runs, :account_id
  end
end
