class AddCustomerMemoryToSaasAiAgents < ActiveRecord::Migration[7.2]
  def change
    add_column :saas_ai_agents, :customer_memory_enabled, :boolean, null: false, default: false

    create_table :saas_ai_agent_memories do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: { to_table: :saas_ai_agents }
      t.references :contact, null: false, foreign_key: true
      t.text :content, null: false, default: ''
      t.jsonb :metadata, null: false, default: {}
      t.bigint :last_processed_message_id
      t.datetime :last_processed_at
      t.timestamps
    end

    add_index :saas_ai_agent_memories, [:account_id, :ai_agent_id, :contact_id], unique: true,
              name: 'index_saas_ai_agent_memories_on_scope'
    add_index :saas_ai_agent_memories, :last_processed_message_id
  end
end
