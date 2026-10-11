class AddContextMessagesLimitToSaasAiAgents < ActiveRecord::Migration[7.1]
  def change
    add_column :saas_ai_agents, :context_messages_limit, :integer, null: false, default: 20
  end
end
