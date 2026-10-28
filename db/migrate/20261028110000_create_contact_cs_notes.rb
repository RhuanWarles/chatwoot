class CreateContactCsNotes < ActiveRecord::Migration[7.1]
  # The CS notes of a contact live apart from the contact on purpose: the contact is sent to every agent (API, events,
  # webhooks), and these values are only for the administrators and the team in charge of customer success.
  def change
    create_table :contact_cs_notes do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id, null: false
      t.jsonb :field_values, null: false, default: {}
      t.timestamps
    end
    add_index :contact_cs_notes, :account_id
    add_index :contact_cs_notes, :contact_id, unique: true
  end
end
