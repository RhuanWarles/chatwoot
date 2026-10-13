class AddResponseBehaviorToSaasAiAgents < ActiveRecord::Migration[7.1]
  def change
    add_column :saas_ai_agents, :response_delay_seconds, :integer, null: false, default: 2
    add_column :saas_ai_agents, :max_messages_per_response, :integer, null: false, default: 3
  end
end
