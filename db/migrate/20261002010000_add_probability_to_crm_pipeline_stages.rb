class AddProbabilityToCrmPipelineStages < ActiveRecord::Migration[7.2]
  def change
    add_column :crm_pipeline_stages, :probability, :integer
  end
end
