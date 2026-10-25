class AddTimezoneToSaasAiAgents < ActiveRecord::Migration[7.2]
  def change
    add_column :saas_ai_agents, :timezone, :string, null: false, default: 'America/Sao_Paulo'
  end
end
