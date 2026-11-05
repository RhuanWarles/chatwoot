class AddFieldAccessAndResolvePermissionToAccountUsers < ActiveRecord::Migration[7.1]
  def change
    # nil means the person sees every field; a list holds the keys of the fields hidden from them.
    add_column :account_users, :hidden_fields, :string, array: true
    add_column :account_users, :can_resolve_conversations, :boolean, default: true, null: false
  end
end
