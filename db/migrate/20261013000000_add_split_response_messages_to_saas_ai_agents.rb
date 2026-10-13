class AddSplitResponseMessagesToSaasAiAgents < ActiveRecord::Migration[7.1]
  def up
    add_column :saas_ai_agents, :split_response_messages, :boolean, null: false, default: true
    execute 'UPDATE saas_ai_agents SET split_response_messages = (max_messages_per_response > 1)'
  end

  def down
    remove_column :saas_ai_agents, :split_response_messages
  end
end
