class AddExpirationToSaasUsageRecords < ActiveRecord::Migration[7.2]
  def change
    add_column :saas_usage_records, :expires_at, :datetime
    add_index :saas_usage_records, [:status, :expires_at]
  end
end
