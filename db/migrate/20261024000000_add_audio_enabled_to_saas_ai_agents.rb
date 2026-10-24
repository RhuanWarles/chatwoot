class AddAudioEnabledToSaasAiAgents < ActiveRecord::Migration[7.1]
  def change
    add_column :saas_ai_agents, :audio_enabled, :boolean, null: false, default: false
  end
end
