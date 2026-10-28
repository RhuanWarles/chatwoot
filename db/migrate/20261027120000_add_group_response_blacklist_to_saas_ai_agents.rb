class AddGroupResponseBlacklistToSaasAiAgents < ActiveRecord::Migration[7.1]
  def change
    add_column :saas_ai_agents, :group_response_blacklist, :jsonb, default: [], null: false
  end
end
