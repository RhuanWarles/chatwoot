class AddAllowedScreensToAccountUsers < ActiveRecord::Migration[7.1]
  def change
    # nil means the person can open every screen their role allows.
    add_column :account_users, :allowed_screens, :string, array: true
  end
end
