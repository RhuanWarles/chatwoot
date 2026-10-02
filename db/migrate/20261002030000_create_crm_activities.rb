class CreateCrmActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_activities do |t|
      t.references :account, null: false
      t.references :deal, null: false
      t.references :contact
      t.references :owner
      t.string :activity_type, null: false
      t.string :title, null: false
      t.text :description
      t.datetime :due_at, null: false
      t.datetime :completed_at
      t.string :status, null: false, default: 'pending'
      t.timestamps
    end
    add_index :crm_activities, [:account_id, :deal_id, :status, :due_at], name: 'index_crm_activities_on_deal_schedule'
  end
end
