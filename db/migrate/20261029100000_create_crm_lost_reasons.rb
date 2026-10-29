class CreateCrmLostReasons < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_lost_reasons do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_lost_reasons, [:account_id, :name], unique: true

    add_reference :crm_deals, :lost_reason, index: true
    add_foreign_key :crm_deals, :crm_lost_reasons, column: :lost_reason_id, on_delete: :nullify
    add_column :crm_deals, :lost_note, :text
  end
end
