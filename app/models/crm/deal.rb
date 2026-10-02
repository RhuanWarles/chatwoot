module Crm
  class Deal < ApplicationRecord
    self.table_name = 'crm_deals'

    STATUSES = %w[open won lost].freeze

    belongs_to :account
    belongs_to :pipeline, class_name: 'Crm::Pipeline'
    belongs_to :pipeline_stage, class_name: 'Crm::PipelineStage'
    belongs_to :contact
    belongs_to :owner, class_name: 'User', optional: true

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :associations_belong_to_account

    private

    def associations_belong_to_account
      errors.add(:pipeline, 'must belong to the same account') if pipeline && pipeline.account_id != account_id
      errors.add(:pipeline_stage, 'must belong to the selected pipeline') if pipeline_stage && pipeline_stage.pipeline_id != pipeline_id
      errors.add(:contact, 'must belong to the same account') if contact && contact.account_id != account_id
      errors.add(:owner, 'must belong to the same account') if owner && !account.users.exists?(id: owner_id)
    end
  end
end
