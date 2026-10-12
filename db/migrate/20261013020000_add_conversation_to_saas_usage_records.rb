class AddConversationToSaasUsageRecords < ActiveRecord::Migration[7.1]
  def change
    add_reference :saas_usage_records, :conversation, null: true, index: true
    add_column :saas_usage_records, :incoming_message_id, :bigint
    add_index :saas_usage_records, :incoming_message_id
  end
end
