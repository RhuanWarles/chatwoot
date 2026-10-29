class Api::V1::Accounts::AutomationRulesController < Api::V1::Accounts::BaseController
  include AttachmentConcern

  before_action :check_authorization
  before_action :fetch_automation_rule, only: [:show, :update, :destroy, :clone, :executions]
  before_action :ensure_execution_delay_allowed, only: [:create, :update]

  def index
    @automation_rules = Current.account.automation_rules
  end

  def show; end

  def create
    blobs, actions, error = validate_and_prepare_attachments(params[:actions])
    return render_could_not_create_error(error) if error

    @automation_rule = Current.account.automation_rules.new(automation_rules_permit)
    @automation_rule.actions = actions
    @automation_rule.conditions = params[:conditions]

    return render_could_not_create_error(@automation_rule.errors.messages) unless @automation_rule.valid?

    @automation_rule.save!
    blobs.each { |blob| @automation_rule.files.attach(blob) }
  end

  def update
    blobs, actions, error = validate_and_prepare_attachments(params[:actions], @automation_rule)
    return render_could_not_create_error(error) if error

    ActiveRecord::Base.transaction do
      @automation_rule.assign_attributes(automation_rules_permit)
      @automation_rule.actions = actions if params[:actions]
      @automation_rule.conditions = params[:conditions] if params[:conditions]
      @automation_rule.save!
      blobs.each { |blob| @automation_rule.files.attach(blob) }
    rescue StandardError => e
      Rails.logger.error e
      render_could_not_create_error(@automation_rule.errors.messages)
    end
  end

  def destroy
    @automation_rule.destroy!
    head :ok
  end

  def clone
    automation_rule = Current.account.automation_rules.find_by(id: params[:automation_rule_id])
    # Dropping the delay here would clone a paused wait into a rule that fires instantly on the
    # next matching event, so refuse rather than rewrite what the rule means.
    return render_delayed_automations_error if automation_rule.execution_delay.present? && !delayed_automations_enabled?

    @automation_rule = automation_rule.dup
    @automation_rule.save!
  end

  def executions
    @executions = @automation_rule.executions.order(created_at: :desc).limit(100)
  end

  private

  def automation_rules_permit
    permitted_attributes = [:name, :description, :event_name, :active]
    permitted_attributes << :execution_delay if delayed_automations_enabled?

    permitted = params.permit(
      *permitted_attributes,
      conditions: [:attribute_key, :filter_operator, :query_operator, :custom_attribute_type, { values: [] }],
      condition_groups: [:operator, { conditions: [:attribute_key, :filter_operator, :query_operator, :custom_attribute_type, { values: [] }] }],
      actions: [:action_name, { action_params: [] }]
    )
    permit_crm_action_params(permitted)
    permitted
  end

  def permit_crm_action_params(permitted)
    crm_keys = %i[deal_id contact_id pipeline_id pipeline_stage_id status value name description owner_id segment_id
                  selection match_status fields custom_fields contact_custom_fields]
    permitted[:actions] ||= []
    Array(params[:actions]).each_with_index do |raw_action, index|
      raw_action = raw_action.to_h.with_indifferent_access
      next unless %w[create_deal update_deal upsert_deal set_deal_fields clear_deal_fields set_contact_fields clear_contact_fields].include?(raw_action[:action_name].to_s)

      raw_params = raw_action[:action_params]
      permitted_action = permitted[:actions][index] ||= ActionController::Parameters.new
      permitted_action[:action_name] ||= raw_action[:action_name]
      if raw_params.is_a?(Array) && raw_params.first.is_a?(Hash)
        raw_params = raw_params.first
        raw_value = raw_params.respond_to?(:permit) ? raw_params.permit(*crm_keys, custom_fields: {}).to_h : raw_params.slice(*crm_keys.map(&:to_s), *crm_keys)
        permitted_action[:action_params] = [raw_value]
      elsif raw_params.is_a?(ActionController::Parameters) || raw_params.is_a?(Hash)
        permitted_action[:action_params] = if raw_params.respond_to?(:permit)
                                                       raw_params.permit(*crm_keys, custom_fields: {}).to_h
                                                     else
                                                       raw_params.slice(*crm_keys.map(&:to_s), *crm_keys).with_indifferent_access
                                                     end
      end
    end
  end

  def ensure_execution_delay_allowed
    return if delayed_automations_enabled?
    return if params[:execution_delay].blank?

    render_delayed_automations_error
  end

  def render_delayed_automations_error
    render json: { error: 'Delayed automations are not enabled for this account.' }, status: :unprocessable_entity
  end

  def delayed_automations_enabled?
    Current.account.feature_enabled?('delayed_automations')
  end

  def fetch_automation_rule
    @automation_rule = Current.account.automation_rules.find_by(id: params[:id])
  end
end
