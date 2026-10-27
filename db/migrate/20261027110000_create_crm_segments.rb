class CreateCrmSegments < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_segments do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :color
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_segments, [:account_id, :name], unique: true

    add_reference :crm_deals, :segment, index: true
    add_foreign_key :crm_deals, :crm_segments, column: :segment_id, on_delete: :nullify
  end
end
