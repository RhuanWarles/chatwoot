require 'digest'

class AutomationRules::ActionService < ActionService
  CRM_ACTIONS = %w[create_deal update_deal upsert_deal].freeze
  CRM_FIELD_ACTIONS = %w[set_deal_fields clear_deal_fields set_contact_fields clear_contact_fields].freeze

  def initialize(rule, account, conversation, context: nil)
    super(conversation)
    @rule = rule
    @account = account
    @context = context || AutomationRules::Context.from(account: account, conversation: conversation, trigger: { event_name: rule.event_name })
    @resolver = AutomationRules::VariableResolver.new(@context)
    Current.executed_by = rule
  end

  def perform
    results = []
    run_execution = begin_run_execution
    @rule.actions.each do |raw_action|
      @conversation.reload if @conversation
      action = raw_action.with_indifferent_access
      action_name = action[:action_name].to_s
      params = @resolver.resolve(action[:action_params])
      execution = begin_execution(action_name, params)
      next results << { action: action_name, status: 'skipped' } if execution == :skipped

      begin
        send(action_name, params)
        finish_execution(execution, 'success')
        results << { action: action_name, status: 'success' }
      rescue StandardError => e
        finish_execution(execution, 'failed', e)
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
        results << { action: action_name, status: 'failed', error: sanitized_error(e) }
      end
    end
    finish_run_execution(run_execution, results)
    results
  ensure
    Current.reset
  end

  private

  def send_attachment(blob_ids)
    return if conversation_a_tweet? || !@rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)
    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation.reload, params).perform
  end

  def send_email_to_team(params)
    Team.where(id: params[0][:team_ids]).each do |team|
      break unless @account.within_email_rate_limit?

      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
      @account.increment_email_sent_count
    end
  end

  def create_deal(params)
    config = action_config(params)
    deal = nil
    Crm::Deal.transaction do
      deal = Crm::Deal.new(deal_attributes(config))
      deal.automation_depth = 1
      deal.save!
      write_deal_custom_fields(deal, config[:custom_fields])
      write_contact_custom_fields(@context.contact, config[:contact_custom_fields])
    end
    @context = @context.with(deal: deal)
    @resolver = AutomationRules::VariableResolver.new(@context)
    deal
  end

  def update_deal(params)
    config = action_config(params)
    deal = find_deal(config)
    raise ActiveRecord::RecordNotFound, 'No CRM deal matched the automation action' unless deal

    Crm::Deal.transaction do
      deal.assign_attributes(deal_attributes(config, include_required: false))
      deal.automation_depth = 1
      deal.save!
      write_deal_custom_fields(deal, config[:custom_fields])
      write_contact_custom_fields(@context.contact, config[:contact_custom_fields])
    end
    @context = @context.with(deal: deal)
    @resolver = AutomationRules::VariableResolver.new(@context)
    deal
  end

  def upsert_deal(params)
    config = action_config(params)
    find_deal(config) ? update_deal(config) : create_deal(config)
  end

  def set_deal_fields(params)
    deal = @context.deal || find_deal(action_config(params))
    raise ActiveRecord::RecordNotFound, 'No CRM deal is available in the automation context' unless deal

    write_deal_custom_fields(deal, action_config(params)[:custom_fields] || action_config(params))
  end

  def clear_deal_fields(params)
    deal = @context.deal || find_deal(action_config(params))
    raise ActiveRecord::RecordNotFound, 'No CRM deal is available in the automation context' unless deal

    keys = action_config(params)[:fields] || action_config(params)[:custom_fields]&.keys || []
    deal.custom_field_values.joins(:custom_field).where(crm_custom_fields: { key: keys }).find_each { |value| value.destroy! }
  end

  def set_contact_fields(params)
    write_contact_custom_fields(@context.contact, action_config(params)[:custom_fields] || action_config(params))
  end

  def clear_contact_fields(params)
    contact = @context.contact
    raise ActiveRecord::RecordNotFound, 'No contact is available in the automation context' unless contact

    keys = action_config(params)[:fields] || action_config(params)[:custom_fields]&.keys || []
    contact.update!(custom_attributes: contact.custom_attributes.except(*keys.map(&:to_s)))
  end

  def action_config(params)
    value = params.is_a?(Array) ? params.first : params
    (value || {}).with_indifferent_access
  end

  def deal_attributes(config, include_required: true)
    pipeline = @account.crm_pipelines.find(config[:pipeline_id]) if config[:pipeline_id].present?
    stage = pipeline&.stages&.find_by(id: config[:pipeline_stage_id])
    stage = @account.crm_pipeline_stages.find_by(id: config[:pipeline_stage_id]) if pipeline.nil? && config[:pipeline_stage_id].present?
    raise ActiveRecord::RecordNotFound, 'CRM pipeline and stage must belong to the account' if config[:pipeline_id].present? && (!pipeline || !stage)
    raise ActiveRecord::RecordNotFound, 'CRM pipeline and stage are required to create a deal' if include_required && (!pipeline || !stage)

    contact = config[:contact_id].present? ? @account.contacts.find(config[:contact_id]) : @context.contact
    raise ActiveRecord::RecordNotFound, 'A contact is required to create a CRM deal' if include_required && !contact

    attrs = if include_required
              { account: @account, contact: contact, name: config[:name].presence || "Deal for #{contact&.name || 'contact'}",
                status: config[:status].presence || 'open', value: config[:value].presence, description: config[:description].presence,
                owner_id: config[:owner_id].presence, segment_id: config[:segment_id].presence }
            else
              { contact: contact, name: config[:name].presence, status: config[:status].presence, value: config[:value].presence,
                description: config[:description].presence, owner_id: config[:owner_id].presence, segment_id: config[:segment_id].presence }
            end
    attrs[:pipeline] = pipeline if pipeline
    attrs[:pipeline_stage] = stage if stage
    attrs.compact
  end

  def find_deal(config)
    if config[:selection].to_s == 'current_deal' && @context.deal&.account_id == @account.id
      return @context.deal
    end

    scope = @account.crm_deals.where(contact_id: config[:contact_id].presence || @context.contact&.id)
    scope = scope.where(id: config[:deal_id]) if config[:deal_id].present?
    scope = scope.where(pipeline_id: config[:pipeline_id]) if config[:pipeline_id].present?
    scope = scope.where(pipeline_stage_id: config[:pipeline_stage_id]) if config[:pipeline_stage_id].present?
    scope = scope.where(status: config[:status]) if config[:status].present? && config[:match_status] == true
    selection = config[:selection].to_s
    scope = scope.where(status: 'open') if selection.blank? || selection == 'first_open'
    selection == 'recent' ? scope.order(updated_at: :desc).first : scope.order(created_at: :asc).first
  end

  def write_deal_custom_fields(deal, values)
    return if values.blank?

    fields = @account.crm_custom_fields.active.where(key: values.keys.map(&:to_s))
    values.each do |key, value|
      field = fields.find { |item| item.key == key.to_s }
      raise ActiveRecord::RecordNotFound, "CRM custom field #{key} not found" unless field

      field_value = deal.custom_field_values.find_or_initialize_by(custom_field: field, account: @account)
      field_value.automation_depth = 1
      field_value.typed_value = value
      field_value.save!
    end
  end

  def write_contact_custom_fields(contact, values)
    return if values.blank?
    raise ActiveRecord::RecordNotFound, 'No contact is available in the automation context' unless contact
    raise ActiveRecord::RecordNotFound, 'Contact belongs to another account' unless contact.account_id == @account.id

    definitions = @account.custom_attribute_definitions.with_attribute_model('contact_attribute')
    attributes = contact.custom_attributes.to_h.stringify_keys
    values.each do |key, value|
      definition = definitions.find_by(attribute_key: key.to_s)
      raise ActiveRecord::RecordNotFound, "Contact custom field #{key} not found" unless definition

      validate_contact_custom_field!(definition, value)
      attributes[key.to_s] = value
    end
    contact.update!(custom_attributes: attributes)
  end

  def validate_contact_custom_field!(definition, value)
    valid = case definition.attribute_display_type
            when 'number', 'currency', 'percent' then value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
            when 'date' then Date.iso8601(value.to_s)
            when 'checkbox' then value.in?([true, false, 'true', 'false'])
            when 'list' then definition.attribute_values.to_a.include?(value)
            else value.is_a?(String) || value.is_a?(Numeric)
            end
    raise ArgumentError, "Invalid value for contact custom field #{definition.attribute_key}" unless valid
  rescue Date::Error
    raise ArgumentError, "Invalid value for contact custom field #{definition.attribute_key}"
  end

  def begin_execution(action_name, params)
    key = (CRM_ACTIONS + CRM_FIELD_ACTIONS).include?(action_name) ? idempotency_key(action_name, params) : nil
    AutomationExecution.create!(account: @account, automation_rule: @rule, conversation: @conversation,
                                contact: @context.contact, deal: @context.deal, action_name: action_name,
                                trigger: @rule.event_name, idempotency_key: key, started_at: Time.current,
                                metadata: { event_name: @rule.event_name })
  rescue ActiveRecord::RecordNotUnique
    :skipped
  end

  def begin_run_execution
    AutomationExecution.create!(account: @account, automation_rule: @rule, conversation: @conversation,
                                contact: @context.contact, deal: @context.deal, action_name: 'automation_run',
                                trigger: @rule.event_name, started_at: Time.current,
                                metadata: { actions: [] })
  end

  def finish_run_execution(execution, results)
    status = if results.empty? || results.all? { |result| result[:status] == 'success' }
               'success'
             elsif results.all? { |result| result[:status] == 'skipped' }
               'skipped'
             elsif results.all? { |result| %w[failed skipped].include?(result[:status]) }
               'failed'
             else
               'partial_success'
             end
    execution.update!(status: status, deal: @context.deal, contact: @context.contact,
                      metadata: { actions: results }, completed_at: Time.current)
  end

  def finish_execution(execution, status, error = nil)
    return if execution == :skipped

    execution.update!(status: status, error_message: sanitized_error(error), deal: @context.deal,
                      contact: @context.contact, completed_at: Time.current)
  end

  def sanitized_error(error)
    return if error.blank?

    error.message.to_s.gsub(/(token|secret|password|api[_-]?key)=?\s*[^\s,;]+/i, '\\1=[REDACTED]').truncate(1000)
  end

  def idempotency_key(action_name, params)
    trigger_id = @context.trigger.is_a?(Hash) ? @context.trigger[:message]&.id : nil
    source = [@rule.id, @conversation&.id, @context.contact&.id, action_name, @rule.event_name, trigger_id,
              @conversation&.updated_at&.to_f, params].to_json
    Digest::SHA256.hexdigest(source)
  end
end
