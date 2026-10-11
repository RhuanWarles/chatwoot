class CreateSaasAiTools < ActiveRecord::Migration[7.1]
  def change
    create_table :saas_ai_tools do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :description, null: false, default: ''
      t.string :tool_type, null: false, default: 'http'
      t.boolean :active, null: false, default: false
      t.boolean :allow_in_playground, null: false, default: false
      t.jsonb :configuration, null: false, default: {}
      t.text :secret_headers
      t.timestamps
    end
    add_index :saas_ai_tools, [:account_id, :slug], unique: true

    create_table :saas_ai_tool_agents do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_tool, null: false, foreign_key: { to_table: :saas_ai_tools }
      t.references :ai_agent, null: false, foreign_key: { to_table: :saas_ai_agents }
      t.timestamps
    end
    add_index :saas_ai_tool_agents, [:ai_tool_id, :ai_agent_id], unique: true
    add_index :saas_ai_tool_agents, [:account_id, :ai_agent_id]

    create_table :saas_ai_tool_executions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: { to_table: :saas_ai_agents }
      t.references :ai_tool, null: false, foreign_key: { to_table: :saas_ai_tools }
      t.references :conversation, foreign_key: true
      t.string :playground_session_id
      t.string :request_id, null: false
      t.jsonb :arguments, null: false, default: {}
      t.string :status, null: false
      t.integer :response_status
      t.integer :duration_ms
      t.string :error_code
      t.timestamps
    end
    add_index :saas_ai_tool_executions, :request_id, unique: true
    add_index :saas_ai_tool_executions, [:account_id, :created_at]
  end
end
