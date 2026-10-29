module Crm
  class Deal < ApplicationRecord
    self.table_name = 'crm_deals'

    STATUSES = %w[open won lost].freeze
    OUTCOMES = %w[won lost].freeze
    TRACKED_CHANGES = {
      'pipeline_id' => 'pipeline_changed', 'pipeline_stage_id' => 'stage_changed', 'status' => 'status_changed',
      'value' => 'value_changed', 'owner_id' => 'owner_changed'
    }.freeze

    attr_accessor :automation_depth

    belongs_to :account
    belongs_to :pipeline, class_name: 'Crm::Pipeline'
    belongs_to :pipeline_stage, class_name: 'Crm::PipelineStage'
    belongs_to :contact
    belongs_to :owner, class_name: 'User', optional: true
    belongs_to :segment, class_name: 'Crm::Segment', optional: true
    has_many :activities, class_name: 'Crm::Activity', dependent: :destroy
    has_many :custom_field_values, class_name: 'Crm::DealCustomFieldValue', dependent: :destroy
    has_many :events, class_name: 'Crm::DealEvent', dependent: :destroy
    after_create :record_creation
    after_update :record_changes
    after_commit :enqueue_stage_automations, on: [:create, :update]
    after_commit :enqueue_outcome_automations, on: [:create, :update]
    after_commit :dispatch_automation_events, on: [:create, :update]

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :associations_belong_to_account

    private

    def enqueue_stage_automations
      return unless previously_new_record? || saved_change_to_pipeline_stage_id?

      Crm::StageAutomationJob.perform_later(id, pipeline_stage_id, automation_depth.to_i) if pipeline_stage.automations.present?
    end

    def enqueue_outcome_automations
      return unless saved_change_to_status? && OUTCOMES.include?(status)

      Crm::OutcomeAutomationJob.perform_later(id, status, automation_depth.to_i) if pipeline.outcome_automations(status).present?
    end

    def record_creation
      events.create!(account_id: account_id, actor: Current.user, event_type: 'deal_created')
    end

    def record_changes
      TRACKED_CHANGES.each do |attribute, event_type|
        next unless saved_change_to_attribute?(attribute)

        before, after = saved_change_to_attribute(attribute)
        metadata = { 'from' => before, 'to' => after }
        if attribute == 'pipeline_id'
          metadata.merge!('from_name' => Crm::Pipeline.find_by(id: before)&.name, 'to_name' => pipeline.name)
        elsif attribute == 'pipeline_stage_id'
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
      errors.add(:segment, 'must belong to the same account') if segment && segment.account_id != account_id
    end

    def dispatch_automation_events
      dispatcher = Rails.configuration.dispatcher
      conversation = contact.conversations.reorder(last_activity_at: :desc).first
      changed = previous_changes
      dispatcher.dispatch(Events::Types::CRM_DEAL_CREATED, Time.zone.now, deal: self, conversation: conversation,
                          changed_attributes: changed, performed_by: Current.executed_by) if previously_new_record?
      return if previously_new_record?

      dispatcher.dispatch(Events::Types::CRM_DEAL_UPDATED, Time.zone.now, deal: self, conversation: conversation,
                          changed_attributes: changed, performed_by: Current.executed_by)
      dispatch_deal_change(dispatcher, changed, conversation)
    end

    def dispatch_deal_change(dispatcher, changed, conversation)
      event_by_attribute = {
        'pipeline_id' => Events::Types::CRM_DEAL_PIPELINE_CHANGED,
        'pipeline_stage_id' => Events::Types::CRM_DEAL_STAGE_CHANGED,
        'status' => Events::Types::CRM_DEAL_STATUS_CHANGED
      }
      event_by_attribute.each do |attribute, event_name|
        next unless changed.key?(attribute)

        dispatcher.dispatch(event_name, Time.zone.now, deal: self, conversation: conversation,
                            changed_attributes: changed, performed_by: Current.executed_by)
      end
    end
  end
end
