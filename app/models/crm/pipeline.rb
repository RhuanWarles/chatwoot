module Crm
  class Pipeline < ApplicationRecord
    include Crm::Automatable

    self.table_name = 'crm_pipelines'

    belongs_to :account
    has_many :stages, class_name: 'Crm::PipelineStage', dependent: :destroy
    has_many :deals, class_name: 'Crm::Deal', dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: { scope: :account_id }
    validates_automations :won_automations, :lost_automations
    scope :active, -> { where(active: true) }

    def outcome_automations(status)
      { 'won' => won_automations, 'lost' => lost_automations }.fetch(status)
    end
  end
end
