class CreateCrmTables < ActiveRecord::Migration[7.2]
  def change
    create_table :crm_pipelines do |t|
      t.references :account, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :crm_pipelines, [:account_id, :name], unique: true

    create_table :crm_pipeline_stages do |t|
      t.references :account, null: false
      t.references :pipeline, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.string :color
      t.timestamps
    end

    add_index :crm_pipeline_stages, [:pipeline_id, :position]

    create_table :crm_deals do |t|
      t.references :account, null: false
      t.references :pipeline, null: false
      t.references :pipeline_stage, null: false
      t.references :contact, null: false
      t.references :owner, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.decimal :value, precision: 15, scale: 2
      t.string :status, null: false, default: 'open'
      t.text :description
      t.timestamps
    end

    add_index :crm_deals, [:account_id, :pipeline_id]
    add_index :crm_deals, [:account_id, :pipeline_stage_id]
    add_index :crm_deals, [:account_id, :contact_id]
  end
end
