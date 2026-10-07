class CreateSaasAiAgents < ActiveRecord::Migration[7.1]
  def change
    create_table :saas_ai_agents do |t|
      t.references :account, null: false
      t.string :name, null: false
      t.text :description
      t.text :system_prompt, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.decimal :temperature, precision: 3, scale: 2, null: false, default: 0.7
      t.boolean :active, null: false, default: false
      t.boolean :handoff_enabled, null: false, default: true
      t.timestamps
    end

    create_table :saas_ai_agent_inboxes do |t|
      t.references :ai_agent, null: false, index: false
      t.references :inbox, null: false
      t.timestamps
    end
    add_index :saas_ai_agent_inboxes, [:ai_agent_id, :inbox_id], unique: true
  end
end
