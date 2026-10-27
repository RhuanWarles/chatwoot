class AddReplyStateToConversations < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    add_column :conversations, :waiting_for_reply, :boolean, default: false, null: false
    add_column :conversations, :last_relevant_message_type, :integer
    add_index :conversations, [:account_id, :status, :waiting_for_reply],
              name: 'index_conversations_on_reply_state', algorithm: :concurrently
    add_index :messages, [:conversation_id, :created_at, :id],
              name: 'index_messages_on_relevant_conversation_created_at',
              where: 'private = FALSE AND message_type IN (0, 1)', algorithm: :concurrently

    backfill_reply_state
  end

  def backfill_reply_state
    execute <<~SQL.squish
      UPDATE conversations
      SET waiting_for_reply = COALESCE(latest.message_type = 0, FALSE),
          last_relevant_message_type = latest.message_type
      FROM (
        SELECT DISTINCT ON (conversation_id)
          conversation_id,
          account_id,
          message_type
        FROM messages
        WHERE private = FALSE
          AND message_type IN (0, 1)
        ORDER BY conversation_id, created_at DESC, id DESC
      ) latest
      WHERE conversations.id = latest.conversation_id
        AND conversations.account_id = latest.account_id
    SQL
  end

  def down
    remove_index :messages, name: 'index_messages_on_relevant_conversation_created_at'
    remove_index :conversations, name: 'index_conversations_on_reply_state'
    remove_column :conversations, :last_relevant_message_type
    remove_column :conversations, :waiting_for_reply
  end
end
