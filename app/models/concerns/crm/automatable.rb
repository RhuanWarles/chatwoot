module Crm::Automatable
  extend ActiveSupport::Concern
  include Crm::AutomationFieldValidations

  MAX_ACTIONS = 50
  MAX_RANDOM_OWNERS = 100
  MAX_ROUTES = 50
  ACTION_KEYS = %w[type status user_id user_ids activity_type title due_in_hours label state content pipeline_id stage_id url
                   custom_field_id value routes fallback condition].freeze
  ROUTE_KEYS = %w[operator value pipeline_id stage_id].freeze
  DESTINATION_KEYS = %w[pipeline_id stage_id].freeze
  CONDITION_KEYS = %w[custom_field_id operator value].freeze
  # Strong-parameters shape of ACTION_KEYS; value is a scalar, or a list for multiselect fields.
  PERMITTED_ACTION_PARAMS = [
    :type, :status, :user_id, :activity_type, :title, :due_in_hours, :label, :state, :content, :pipeline_id, :stage_id, :url,
    :custom_field_id, :value,
    { user_ids: [], value: [], routes: ROUTE_KEYS.map(&:to_sym), fallback: DESTINATION_KEYS.map(&:to_sym),
      condition: CONDITION_KEYS.map(&:to_sym) }
  ].freeze
  ACTION_VALIDATORS = {
    'set_status' => :valid_set_status?,
    'assign_owner' => :valid_assign_owner?,
    'assign_random' => :valid_assign_random?,
    'set_field' => :valid_set_field?,
    'route_by_field' => :valid_route_by_field?,
    'create_activity' => :valid_create_activity?,
    'add_label' => :valid_add_label?,
    'set_ai_state' => :valid_set_ai_state?,
    'send_message' => :valid_send_message?,
    'move_stage' => :valid_move_stage?,
    'send_webhook' => :valid_send_webhook?
  }.freeze

  class_methods do
    # Only lists being changed are validated, so a stale reference such as a deleted stage never blocks
    # unrelated edits like CrmPipelines.vue toggling {pipeline: {active}}.
    def validates_automations(*attributes)
      validate do
        attributes.each do |attribute|
          next unless will_save_change_to_attribute?(attribute)

          actions = public_send(attribute)
          valid = actions.is_a?(Array) && actions.length <= MAX_ACTIONS && actions.all? { |action| valid_automation?(action) }
          errors.add(attribute, 'invalid') unless valid
        end
      end
    end
  end

  private

  def valid_automation?(action)
    return false unless action.is_a?(Hash) && (action.keys - ACTION_KEYS).empty?

    validator = ACTION_VALIDATORS[action['type']]
    validator && send(validator, action) && valid_condition?(action['condition'])
  end

  def valid_set_status?(action)
    Crm::Deal::STATUSES.include?(action['status'])
  end

  def valid_assign_owner?(action)
    action['user_id'].is_a?(Integer) && account.users.exists?(id: action['user_id'])
  end

  def valid_create_activity?(action)
    Crm::Activity::TYPES.include?(action['activity_type']) && action['title'].to_s.strip.present? && action['title'].length <= 255 &&
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
    uri = URI.parse(action['url'].to_s)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end
end
