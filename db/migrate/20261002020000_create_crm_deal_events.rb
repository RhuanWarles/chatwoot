class CreateCrmDealEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :crm_deal_events do |t|
      t.references :account, null: false
      t.references :deal, null: false
      t.references :actor
      t.string :event_type, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :crm_deal_events, [:account_id, :deal_id, :created_at, :id], name: 'index_crm_deal_events_on_timeline'
    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO crm_deal_events (account_id, deal_id, event_type, metadata, created_at, updated_at)
          SELECT account_id, id, 'deal_created', '{}', created_at, created_at FROM crm_deals
        SQL
      end
    end
  end
end
