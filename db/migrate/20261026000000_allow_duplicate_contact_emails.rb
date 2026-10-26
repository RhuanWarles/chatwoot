class AllowDuplicateContactEmails < ActiveRecord::Migration[7.2]
  def up
    remove_index :contacts, name: 'uniq_email_per_account_contact'
  end

  def down
    add_index :contacts, %i[email account_id], name: 'uniq_email_per_account_contact', unique: true
  end
end
