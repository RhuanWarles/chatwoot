class AddSystemKeyToCrmCustomFields < ActiveRecord::Migration[7.1]
  def change
    # Marks the fields the system creates and keeps (the lost reason), so a person cannot delete or reshape them.
    add_column :crm_custom_fields, :system_key, :string
    add_index :crm_custom_fields, [:account_id, :system_key], unique: true, where: 'system_key IS NOT NULL',
                                                              name: 'index_crm_custom_fields_on_account_id_and_system_key'
  end
end
