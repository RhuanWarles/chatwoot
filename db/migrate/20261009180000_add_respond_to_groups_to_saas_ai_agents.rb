class AddRespondToGroupsToSaasAiAgents < ActiveRecord::Migration[7.1]
  def change
    add_column :saas_ai_agents, :respond_to_groups, :boolean, default: false, null: false
  end
end
