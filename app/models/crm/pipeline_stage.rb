module Crm
  class PipelineStage < ApplicationRecord
    self.table_name = 'crm_pipeline_stages'

    belongs_to :account
    belongs_to :pipeline, class_name: 'Crm::Pipeline'
    has_many :deals, class_name: 'Crm::Deal', dependent: :restrict_with_error

    validates :name, :position, presence: true
    validate :pipeline_belongs_to_account

    default_scope { order(:position, :id) }

    private

    def pipeline_belongs_to_account
      errors.add(:pipeline, 'must belong to the same account') if pipeline && pipeline.account_id != account_id
    end
  end
end
