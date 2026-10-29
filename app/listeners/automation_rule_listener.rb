class AutomationRuleListener < BaseListener
  CRM_EVENT_NAMES = %w[
    crm_deal_created crm_deal_updated crm_deal_stage_changed crm_deal_status_changed crm_deal_pipeline_changed
    crm_deal_field_changed
  ].freeze

  CRM_EVENT_NAMES.each do |rule_event|
    define_method(rule_event) { |event| process_deal_event(event, rule_event) }
  end

  def contact_created(event)
    process_contact_event(event, 'contact_created')
  end

  def contact_updated(event)
    process_contact_event(event, 'contact_updated')
  end

  def conversation_updated(event)
    process_conversation_event(event, 'conversation_updated')
  end

  def conversation_created(event)
    process_conversation_event(event, 'conversation_created')
  end

  def conversation_opened(event)
    process_conversation_event(event, 'conversation_opened')
  end

  def conversation_resolved(event)
    process_conversation_event(event, 'conversation_resolved')
  end

  def message_created(event)
    message = event.data[:message]

    return if ignore_message_created_event?(event)

    account = message.try(:account)
    changed_attributes = event.data[:changed_attributes]

    return unless rule_present?('message_created', account)

    rules = current_account_rules('message_created', account)

    rules.each do |rule|
      conditions_match = ::AutomationRules::ConditionsFilterService.new(rule, message.conversation,
                                                                        { message: message, changed_attributes: changed_attributes }).perform
      execute_rule(rule, account, message.conversation, message: message, changed_attributes: changed_attributes) if conditions_match.present?
    end
  end

  private

  def process_conversation_event(event, event_name)
    return if performed_by_automation?(event)

    auto_reply_skip_events = %w[conversation_created conversation_opened]
    return if auto_reply_skip_events.include?(event_name) && ignore_auto_reply_event?(event)

    conversation = event.data[:conversation]
    account = conversation.account
    changed_attributes = event.data[:changed_attributes]

    rules = conversation_rules(event_name, account)
    return if rules.blank?

    rules.each do |rule|
      conditions_match = ::AutomationRules::ConditionsFilterService.new(rule, conversation, { changed_attributes: changed_attributes }).perform
      execute_rule(rule, account, conversation, changed_attributes: changed_attributes) if conditions_match.present?
    end
  end

  # A delayed conversation rule reads as "the conversation has been in this status for N minutes",
  # so a conversation created in that status must arm it too. Creation never dispatches
  # CONVERSATION_UPDATED, and both paths key the episode on the same status_changed_at, so a later
  # update arming the same episode is deduped by the unique index.
  def conversation_rules(event_name, account)
    rules = current_account_rules(event_name, account)
    return rules unless event_name == 'conversation_created'

    rules + current_account_rules('conversation_updated', account).where.not(execution_delay: nil)
  end

  # Delayed rules record a pending execution instead of acting; the sweep re-checks and
  # runs them at due time. Flag off means no arming and no immediate fallback — a delayed
  # message silently becoming instant is worse than skipping.
  def execute_rule(rule, account, conversation, message: nil, changed_attributes: {}, deal: nil)
    if rule.execution_delay.present?
      return if conversation.blank?
      return unless account.feature_enabled?('delayed_automations')

      AutomationRulePendingExecution.schedule(rule: rule, conversation: conversation, message: message)
    else
      if deal
        context = ::AutomationRules::Context.from(
          account: account,
          conversation: conversation,
          trigger: { event_name: rule.event_name, message: message },
          event_changes: changed_attributes,
          deal: deal
        )
        ::AutomationRules::ActionService.new(rule, account, conversation, context: context).perform
      else
        ::AutomationRules::ActionService.new(rule, account, conversation).perform
      end
    end
  end

  def process_deal_event(event, event_name)
    deal = event.data[:deal]
    return if deal.blank? || performed_by_automation?(event)

    conversation = event.data[:conversation]
    account = deal.account
    current_account_rules(event_name, account).each do |rule|
      conditions_match = ::AutomationRules::ConditionsFilterService.new(
        rule, conversation, deal: deal, changed_attributes: event.data[:changed_attributes]
      ).perform
      execute_rule(rule, account, conversation, changed_attributes: event.data[:changed_attributes], deal: deal) if conditions_match
    end
  end

  def process_contact_event(event, event_name)
    contact = event.data[:contact]
    return if contact.blank? || performed_by_automation?(event)

    conversation = contact.conversations.reorder(last_activity_at: :desc).first
    current_account_rules(event_name, contact.account).each do |rule|
      conditions_match = ::AutomationRules::ConditionsFilterService.new(
        rule, conversation, contact: contact, changed_attributes: event.data[:changed_attributes]
      ).perform
      next unless conditions_match

      context = ::AutomationRules::Context.from(
        account: contact.account, conversation: conversation, contact: contact,
        trigger: { event_name: rule.event_name }, event_changes: event.data[:changed_attributes]
      )
      ::AutomationRules::ActionService.new(rule, contact.account, conversation, context: context).perform
    end
  end

  def rule_present?(event_name, account)
    return if account.blank?

    current_account_rules(event_name, account).any?
  end

  def current_account_rules(event_name, account)
    AutomationRule.where(
      event_name: event_name,
      account_id: account.id,
      active: true
    )
  end

  def performed_by_automation?(event)
    event.data[:performed_by].present? && event.data[:performed_by].instance_of?(AutomationRule)
  end

  def ignore_auto_reply_event?(event)
    conversation = event.data[:conversation]
    conversation.additional_attributes['auto_reply'].present?
  end

  def ignore_message_created_event?(event)
    message = event.data[:message]
    performed_by_automation?(event) || message.activity? || message.auto_reply_email?
  end
end
