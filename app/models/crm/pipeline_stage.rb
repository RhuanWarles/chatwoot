module Crm
  class PipelineStage < ApplicationRecord
    self.table_name = 'crm_pipeline_stages'

    belongs_to :account
    belongs_to :pipeline, class_name: 'Crm::Pipeline'
    has_many :deals, class_name: 'Crm::Deal', dependent: :restrict_with_error

    validates :name, :position, presence: true
    validates :probability, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
    validate :pipeline_belongs_to_account
    validate :valid_automations

    default_scope { order(:position, :id) }

    AUTOMATION_KEYS = %w[type status user_id activity_type title due_in_hours label state content pipeline_id stage_id url].freeze

    private

    def valid_automations
      valid = automations.is_a?(Array) && automations.length <= 10 && automations.all? { |action| valid_automation?(action) }
      errors.add(:automations, 'invalid') unless valid
    end

    def valid_automation?(action)
      return false unless action.is_a?(Hash) && (action.keys - AUTOMATION_KEYS).empty?

      case action['type']
      when 'set_status' then Crm::Deal::STATUSES.include?(action['status'])
      when 'assign_owner' then action['user_id'].is_a?(Integer) && account.users.exists?(id: action['user_id'])
      when 'create_activity'
        Crm::Activity::TYPES.include?(action['activity_type']) && action['title'].to_s.strip.present? && action['due_in_hours'].is_a?(Integer) &&
          action['due_in_hours'].between?(1, 24 * 90)
      when 'add_label' then action['label'].to_s.strip.present?
      when 'set_ai_state' then Saas::AiAgents::ConversationState::STATES.include?(action['state'])
      when 'send_message' then action['content'].is_a?(String) && action['content'].strip.present? && action['content'].length <= 2000
      when 'move_stage'
        action['pipeline_id'].is_a?(Integer) && action['stage_id'].is_a?(Integer) &&
          account.crm_pipeline_stages.exists?(id: action['stage_id'], pipeline_id: action['pipeline_id'])
      when 'send_webhook' then action['url'].is_a?(String) && action['url'].match?(URI::DEFAULT_PARSER.make_regexp(%w[http https]))
      else false
      end
    end

    def pipeline_belongs_to_account
      errors.add(:pipeline, 'must belong to the same account') if pipeline && pipeline.account_id != account_id
    end
  end
end
