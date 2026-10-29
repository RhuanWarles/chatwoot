class AutomationWorkflowListener < BaseListener
  DEAL_EVENTS = %w[
    crm_deal_created crm_deal_updated crm_deal_stage_changed crm_deal_status_changed crm_deal_pipeline_changed crm_deal_field_changed
  ].freeze
  OUTCOME_EVENTS = { 'won' => 'crm_deal_won', 'lost' => 'crm_deal_lost' }.freeze

  %w[conversation_created conversation_opened conversation_resolved assignee_changed team_changed].each do |event_name|
    define_method(event_name) { |event| fire_conversation_event(event, event_name) }
  end

  DEAL_EVENTS.each do |event_name|
    define_method(event_name) { |event| fire_deal_event(event, event_name) }
  end

  def message_created(event)
    message = event.data[:message]
    return if message.activity? || message.account.blank?

    conversation = message.conversation
    fire(message.account, 'message_created', event, conversation_id: conversation.id, contact_id: conversation.contact_id, message_id: message.id)
  end

  def contact_created(event)
    fire_contact_event(event, 'contact_created')
  end

  def contact_updated(event)
    fire_contact_event(event, 'contact_updated')
  end

  private

  def fire_conversation_event(event, event_name)
    conversation = event.data[:conversation]
    fire(conversation.account, event_name, event, conversation_id: conversation.id, contact_id: conversation.contact_id)
  end

  def fire_contact_event(event, event_name)
    contact = event.data[:contact]
    fire(contact.account, event_name, event, contact_id: contact.id) if contact.present?
  end

  # A status change to won or lost also starts the workflows that listen to the outcome itself.
  def fire_deal_event(event, event_name)
    deal = event.data[:deal]
    return if deal.blank?

    ids = { deal_id: deal.id, contact_id: deal.contact_id, conversation_id: event.data[:conversation]&.id,
            automation_depth: event.data[:automation_depth], custom_field_id: event.data[:custom_field_id] }
    fire(deal.account, event_name, event, **ids)
    outcome_event = OUTCOME_EVENTS[deal.status]
    fire(deal.account, outcome_event, event, **ids) if event_name == 'crm_deal_status_changed' && outcome_event
  end

  def fire(account, trigger, event, **ids)
    changes = event.data[:changed_attributes]
    context = ids.stringify_keys.compact
    context['changes'] = changes.to_h.slice(*Workflows::Context::CHANGE_KEYS) if changes.present?
    Workflows::TriggerService.fire(account: account, event: trigger, context: context, performed_by: event.data[:performed_by])
  end
end
