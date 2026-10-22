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
    AUTOMATION_VALIDATORS = {
      'set_status' => :valid_set_status?,
      'assign_owner' => :valid_assign_owner?,
      'create_activity' => :valid_create_activity?,
      'add_label' => :valid_add_label?,
      'set_ai_state' => :valid_set_ai_state?,
      'send_message' => :valid_send_message?,
      'move_stage' => :valid_move_stage?,
      'send_webhook' => :valid_send_webhook?
    }.freeze

    private

    def valid_automations
      valid = automations.is_a?(Array) && automations.length <= 10 && automations.all? { |action| valid_automation?(action) }
      errors.add(:automations, 'invalid') unless valid
    end

    def valid_automation?(action)
      return false unless action.is_a?(Hash) && (action.keys - AUTOMATION_KEYS).empty?

      validator = AUTOMATION_VALIDATORS[action['type']]
      validator && send(validator, action)
    end

    def valid_set_status?(action)
      Crm::Deal::STATUSES.include?(action['status'])
    end

    def valid_assign_owner?(action)
      action['user_id'].is_a?(Integer) && account.users.exists?(id: action['user_id'])
    end

    def valid_create_activity?(action)
      Crm::Activity::TYPES.include?(action['activity_type']) && action['title'].to_s.strip.present? &&
        action['due_in_hours'].is_a?(Integer) && action['due_in_hours'].between?(1, 24 * 90)
    end

    def valid_add_label?(action)
      action['label'].to_s.strip.present?
    end

    def valid_set_ai_state?(action)
      Saas::AiAgents::ConversationState::STATES.include?(action['state'])
    end

    def valid_send_message?(action)
      action['content'].is_a?(String) && action['content'].strip.present? && action['content'].length <= 2000
    end

    def valid_move_stage?(action)
      action['pipeline_id'].is_a?(Integer) && action['stage_id'].is_a?(Integer) &&
        account.crm_pipeline_stages.exists?(id: action['stage_id'], pipeline_id: action['pipeline_id'])
    end

    def valid_send_webhook?(action)
      action['url'].is_a?(String) && action['url'].match?(URI::DEFAULT_PARSER.make_regexp(%w[http https]))
    end

    def pipeline_belongs_to_account
      errors.add(:pipeline, 'must belong to the same account') if pipeline && pipeline.account_id != account_id
    end
  end
end
