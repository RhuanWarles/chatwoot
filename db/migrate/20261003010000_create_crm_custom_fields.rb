class CreateCrmCustomFields < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_custom_fields do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.string :field_type, null: false, default: 'text'
      t.boolean :required, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.jsonb :options, null: false, default: []
      t.timestamps
    end
    add_index :crm_custom_fields, [:account_id, :key], unique: true
    add_index :crm_custom_fields, [:account_id, :position]

    create_table :crm_deal_custom_field_values do |t|
      t.references :account, null: false, foreign_key: true
      t.references :deal, null: false, foreign_key: { to_table: :crm_deals }
      t.references :custom_field, null: false, foreign_key: { to_table: :crm_custom_fields }
      t.text :value
      t.timestamps
    end
    add_index :crm_deal_custom_field_values, [:deal_id, :custom_field_id], unique: true, name: 'idx_crm_deal_custom_values_unique'
    add_index :crm_deal_custom_field_values, [:account_id, :custom_field_id], name: 'idx_crm_deal_custom_account_field'
  end
end
