class Crm::StageAutomationService
  # Stops automations that keep moving the card or flipping its status back and forth.
  MAX_DEPTH = 5
  WEBHOOK_EVENTS = {
    'stage' => 'crm_deal_stage_entered', 'won' => 'crm_deal_won', 'lost' => 'crm_deal_lost', 'field' => 'crm_deal_field_changed'
  }.freeze

  def initialize(deal, depth: 0, trigger: 'stage', field_id: nil)
    @deal = deal
    @depth = depth
    @trigger = trigger
    @field_id = field_id
    # Changes made by the actions enqueue their follow-up automations one level deeper.
    @deal.automation_depth = depth + 1
  end

  def perform
    results = actions.map do |action|
      skipped = !condition_met?(action['condition'])
      run(action) unless skipped
      { type: action['type'], ok: true }.tap { |result| result[:skipped] = true if skipped }
    rescue StandardError => e
      # A failed update! leaves its rejected attributes on the shared deal; drop them so later actions start clean.
      @deal.restore_attributes
      Rails.logger.error({ event: 'crm_stage_automation', deal_id: @deal.id, trigger: @trigger,
                           action: action['type'], error: e.message }.to_json)
      { type: action['type'], ok: false }
    end
    return if results.empty?

    @deal.events.create!(account_id: @deal.account_id, event_type: 'automation_run', metadata: { trigger: @trigger, actions: results })
  end

  private

  def actions
    case @trigger
    when 'stage' then @deal.pipeline_stage.automations
    when 'field' then field_actions
    else @deal.pipeline.outcome_automations(@trigger)
    end
  end

  # A field change only runs the actions that look at that field, so unrelated actions never repeat on every edit.
  def field_actions
    @deal.pipeline.field_automations.select { |action| watched_field_id(action) == @field_id }
  end

  def watched_field_id(action)
    action['type'] == 'route_by_field' ? action['custom_field_id'] : action.dig('condition', 'custom_field_id')
  end

  def condition_met?(condition)
    return true if condition.blank?

    Crm::FieldCondition.met?(@deal, condition['custom_field_id'], condition['operator'], condition['value'])
  end

  def ensure_depth_left!
    raise "automation depth limit (#{MAX_DEPTH}) reached" if @depth >= MAX_DEPTH
  end

  def run(action)
    handler = {
      'set_status' => :update_status,
      'assign_owner' => :assign_owner,
      'assign_random' => :assign_random,
      'set_field' => :set_field,
      'route_by_field' => :route_by_field,
      'create_activity' => :create_activity,
      'add_label' => :add_label,
      'set_ai_state' => :update_ai_state,
      'send_message' => :send_message,
      'move_stage' => :move_stage,
      'send_webhook' => :send_webhook
    }[action['type']]
    send(handler, action) if handler
  end

  def update_status(action)
    ensure_depth_left!
    @deal.update!(status: action['status'])
  end

  def assign_owner(action)
    @deal.update!(owner_id: action['user_id'])
  end

  # Spreads new leads evenly (in the long run) between the chosen sellers without having to build one automation per seller.
  def assign_random(action)
    @deal.update!(owner_id: action['user_ids'].sample)
  end

  def set_field(action)
    # Writing a field can trigger the pipeline's field automations, which may write it back.
    ensure_depth_left!
    record = @deal.custom_field_values.find_or_initialize_by(custom_field_id: action['custom_field_id'])
    record.account_id = @deal.account_id
    record.automation_depth = @deal.automation_depth
    record.typed_value = action['value']
    record.save!
  end

  # The first route whose rule matches the field wins; the fallback (if any) catches everything else.
  def route_by_field(action)
    field_id = action['custom_field_id']
    route = action['routes'].find { |item| Crm::FieldCondition.met?(@deal, field_id, item['operator'], item['value']) }
    route ||= action['fallback']
    return unless route

    ensure_depth_left!
    @deal.update!(pipeline_id: route['pipeline_id'], pipeline_stage_id: route['stage_id'])
  end

  def create_activity(action)
    @deal.activities.create!(
      account_id: @deal.account_id, contact_id: @deal.contact_id, owner_id: @deal.owner_id,
      activity_type: action['activity_type'], title: action['title'], due_at: action['due_in_hours'].hours.from_now
    )
  end

  def add_label(action)
    latest_conversation&.add_labels([action['label']])
  end

  def update_ai_state(action)
    conversation = latest_conversation
    return unless conversation

    Saas::AiAgents::ConversationState.update!(conversation: conversation, state: action['state'], user: @deal.owner)
  end

  def send_message(action)
    conversation = latest_conversation
    return unless conversation

    Messages::MessageBuilder.new(nil, conversation, { content: render(action['content']), private: false }).perform
  end

  def move_stage(action)
    ensure_depth_left!
    @deal.update!(pipeline_id: action['pipeline_id'], pipeline_stage_id: action['stage_id'])
  end

  def send_webhook(action)
    Webhooks::Trigger.execute(action['url'], webhook_payload, :account_webhook)
  end

  def render(content)
    content.gsub(/\{\{\s*(\w+)\s*\}\}/) { template_variables.fetch(Regexp.last_match(1), '').to_s }
  end

  def template_variables
    @template_variables ||= {
      'lead_name' => @deal.name, 'contact_name' => @deal.contact.name, 'first_name' => @deal.contact.name.to_s.split.first,
      'stage_name' => @deal.pipeline_stage.name, 'pipeline_name' => @deal.pipeline.name, 'owner_name' => @deal.owner&.name,
      'lost_reason' => @deal.lost_reason&.name
    }
  end

  def webhook_payload
    {
      event: WEBHOOK_EVENTS.fetch(@trigger),
      account_id: @deal.account_id,
      lead: lead_payload,
      contact: contact_payload,
      conversation: conversation_payload
    }
  end

  def lead_payload
    {
      id: @deal.id, name: @deal.name, value: @deal.value&.to_f, status: @deal.status, description: @deal.description,
      lost_reason: @deal.lost_reason&.then { |reason| { id: reason.id, name: reason.name } }, lost_note: @deal.lost_note,
      created_at: @deal.created_at, updated_at: @deal.updated_at,
      pipeline: { id: @deal.pipeline_id, name: @deal.pipeline.name },
      stage: { id: @deal.pipeline_stage_id, name: @deal.pipeline_stage.name, probability: @deal.pipeline_stage.probability },
      owner: @deal.owner && { id: @deal.owner.id, name: @deal.owner.name, email: @deal.owner.email },
      custom_fields: custom_fields
    }
  end

  def contact_payload
    contact = @deal.contact
    {
      id: contact.id, name: contact.name, phone_number: contact.phone_number, email: contact.email,
      identifier: contact.identifier, custom_attributes: contact.custom_attributes, labels: contact.label_list
    }
  end

  def conversation_payload
    latest_conversation&.then do |conversation|
      { id: conversation.display_id, status: conversation.status, labels: conversation.label_list }
    end
  end

  def custom_fields
    @deal.custom_field_values.includes(:custom_field).to_h { |item| [item.custom_field.key, item.typed_value] }
  end

  def latest_conversation
    @latest_conversation ||= @deal.contact.conversations.reorder(last_activity_at: :desc).first
  end
end
