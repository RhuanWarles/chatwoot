module Crm
  class Deal < ApplicationRecord
    self.table_name = 'crm_deals'

    STATUSES = %w[open won lost].freeze
    TRACKED_CHANGES = {
      'pipeline_stage_id' => 'stage_changed', 'status' => 'status_changed',
      'value' => 'value_changed', 'owner_id' => 'owner_changed'
    }.freeze

    belongs_to :account
    belongs_to :pipeline, class_name: 'Crm::Pipeline'
    belongs_to :pipeline_stage, class_name: 'Crm::PipelineStage'
    belongs_to :contact
    belongs_to :owner, class_name: 'User', optional: true
    has_many :events, class_name: 'Crm::DealEvent', dependent: :destroy
    after_create :record_creation
    after_update :record_changes

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :associations_belong_to_account

    private

    def record_creation
      events.create!(account_id: account_id, actor: Current.user, event_type: 'deal_created')
    end

    def record_changes
      TRACKED_CHANGES.each do |attribute, event_type|
        next unless saved_change_to_attribute?(attribute)

        before, after = saved_change_to_attribute(attribute)
        metadata = { 'from' => before, 'to' => after }
        if attribute == 'pipeline_stage_id'
          metadata.merge!('from_name' => Crm::PipelineStage.find_by(id: before)&.name, 'to_name' => pipeline_stage.name)
        elsif attribute == 'owner_id'
          metadata.merge!('from_name' => User.find_by(id: before)&.name, 'to_name' => owner&.name)
        end
        events.create!(account_id: account_id, actor: Current.user, event_type: event_type, metadata: metadata)
      end
    end

    def associations_belong_to_account
      errors.add(:pipeline, 'must belong to the same account') if pipeline && pipeline.account_id != account_id
      errors.add(:pipeline_stage, 'must belong to the selected pipeline') if pipeline_stage && pipeline_stage.pipeline_id != pipeline_id
      errors.add(:contact, 'must belong to the same account') if contact && contact.account_id != account_id
      errors.add(:owner, 'must belong to the same account') if owner && !account.users.exists?(id: owner_id)
    end
  end
end
