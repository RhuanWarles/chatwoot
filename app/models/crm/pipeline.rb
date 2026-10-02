module Crm
  class Pipeline < ApplicationRecord
    self.table_name = 'crm_pipelines'

    belongs_to :account
    has_many :stages, class_name: 'Crm::PipelineStage', dependent: :destroy
    has_many :deals, class_name: 'Crm::Deal', dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: { scope: :account_id }
    scope :active, -> { where(active: true) }
  end
end
