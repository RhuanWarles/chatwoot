class AddAiUsageAnalytics < ActiveRecord::Migration[7.2]
  def up
    add_reference :saas_usage_records, :account, null: true, index: false
    add_column :saas_usage_records, :source, :string, null: false, default: 'runtime'
    add_column :saas_usage_records, :provider, :string
    add_column :saas_usage_records, :model, :string
    add_column :saas_usage_records, :prompt_tokens, :integer
    add_column :saas_usage_records, :completion_tokens, :integer
    add_column :saas_usage_records, :total_tokens, :integer
    add_column :saas_usage_records, :cached_tokens, :integer
    add_column :saas_usage_records, :reasoning_tokens, :integer
    add_column :saas_usage_records, :duration_ms, :integer
    add_column :saas_usage_records, :estimated_cost_usd, :decimal, precision: 20, scale: 10
    add_column :saas_usage_records, :pricing_snapshot, :jsonb, null: false, default: {}
    add_column :saas_usage_records, :error_code, :string
    change_column_null :saas_usage_records, :wallet_id, true

    execute <<~SQL.squish
      UPDATE saas_usage_records
      SET account_id = saas_wallets.account_id
      FROM saas_wallets
      WHERE saas_usage_records.wallet_id = saas_wallets.id
    SQL

    change_column_null :saas_usage_records, :account_id, false
    add_index :saas_usage_records, :account_id
    add_index :saas_usage_records, [:account_id, :source, :created_at], name: 'index_saas_usage_records_on_account_source_created'
  end

  def down
    remove_index :saas_usage_records, name: 'index_saas_usage_records_on_account_source_created'
    remove_index :saas_usage_records, :account_id
    change_column_null :saas_usage_records, :wallet_id, false
    remove_columns :saas_usage_records, :account_id, :source, :provider, :model, :prompt_tokens,
                   :completion_tokens, :total_tokens, :cached_tokens, :reasoning_tokens, :duration_ms,
                   :estimated_cost_usd, :pricing_snapshot, :error_code
  end
end
