class Crm::StageAutomationService
  # Stops stage automations that move cards back and forth between stages.
  MAX_DEPTH = 5

  def initialize(deal, depth: 0)
    @deal = deal
    @depth = depth
  end

  def perform
    @deal.pipeline_stage.automations.each do |action|
      run(action)
    rescue StandardError => e
      Rails.logger.error({ event: 'crm_stage_automation', deal_id: @deal.id, action: action['type'], error: e.message }.to_json)
    end
  end

  private

  def run(action)
    handler = {
      'set_status' => :update_status,
      'assign_owner' => :assign_owner,
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
    @deal.update!(status: action['status'])
  end

  def assign_owner(action)
    @deal.update!(owner_id: action['user_id'])
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
    return if @depth >= MAX_DEPTH

    @deal.automation_depth = @depth + 1
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
      'stage_name' => @deal.pipeline_stage.name, 'pipeline_name' => @deal.pipeline.name, 'owner_name' => @deal.owner&.name
    }
  end

  def webhook_payload
    {
      event: 'crm_deal_stage_entered',
      account_id: @deal.account_id,
      lead: lead_payload,
      contact: contact_payload,
      conversation: conversation_payload
    }
  end

  def lead_payload
    {
      id: @deal.id, name: @deal.name, value: @deal.value&.to_f, status: @deal.status, description: @deal.description,
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
