class CreateEvolutionGroupRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :evolution_group_requests do |t|
      t.bigint :account_id, null: false
      t.bigint :inbox_id, null: false
      t.bigint :user_id, null: false
      t.string :request_id, null: false
      t.string :payload_digest, null: false
      t.datetime :attempted_at
      t.string :group_jid
      t.jsonb :metadata, null: false, default: {}
      t.bigint :conversation_id
      t.timestamps
    end
    add_index :evolution_group_requests, [:account_id, :request_id], unique: true
    add_index :evolution_group_requests, :inbox_id
  end
end
