class CreateSaasVoiceAgents < ActiveRecord::Migration[7.1]
  def change
    create_table :saas_voice_agents do |t|
      t.references :account, null: false
      t.string :name, null: false
      t.text :description
      t.string :provider, null: false, default: 'vapi'
      t.boolean :active, null: false, default: false
      t.string :assistant_id
      t.string :phone_number_id
      t.boolean :inbound_enabled, null: false, default: false
      t.boolean :outbound_enabled, null: false, default: false
      t.integer :max_call_duration
      t.timestamps
    end
  end
end
