class ActionCableListener < BaseListener
  include Events::Types

  def notification_created(event)
    notification, account, unread_count, count = extract_notification_and_account(event)
    tokens = [event.data[:notification].user.pubsub_token]
    broadcast(account, tokens, NOTIFICATION_CREATED, { notification: notification.push_event_data, unread_count: unread_count, count: count })
  end

  def notification_updated(event)
    notification, account, unread_count, count = extract_notification_and_account(event)
    tokens = [event.data[:notification].user.pubsub_token]
    broadcast(account, tokens, NOTIFICATION_UPDATED, { notification: notification.push_event_data, unread_count: unread_count, count: count })
  end

  def notification_deleted(event)
    notification_data = event.data[:notification_data]

    user = User.find_by(id: notification_data[:user_id])
    account = Account.find_by(id: notification_data[:account_id])
    return if user.blank? || account.blank?

    notification_finder = NotificationFinder.new(user, account)
    tokens = [user.pubsub_token]
    broadcast(account, tokens, NOTIFICATION_DELETED, {
                notification: { id: notification_data[:id] },
                unread_count: notification_finder.unread_count,
                count: notification_finder.count
              })
  end

  def account_cache_invalidated(event)
    account = event.data[:account]
    tokens = user_tokens(account, account.agents)

    broadcast(account, tokens, ACCOUNT_CACHE_INVALIDATED, {
                cache_keys: event.data[:cache_keys]
              })
  end

  def message_created(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = conversation_tokens(account, conversation) + contact_tokens(conversation.contact_inbox, message)

    broadcast(account, tokens, MESSAGE_CREATED, message.push_event_data)
  end

  def message_updated(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = conversation_tokens(account, conversation) + contact_tokens(conversation.contact_inbox, message)

    broadcast(account, tokens, MESSAGE_UPDATED, message.push_event_data.merge(previous_changes: event.data[:previous_changes]))
  end

  # Reactions only update existing bubbles; do not notify bots or delivery webhooks.
  def message_reaction_updated(event)
    message_updated(event)
  end

  def first_reply_created(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = conversation_tokens(account, conversation)

    broadcast(account, tokens, FIRST_REPLY_CREATED, message.push_event_data)
  end

  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, CONVERSATION_CREATED, conversation.push_event_data)
  end

  def conversation_bot_handoff(event)
    broadcast_to_inbox_members(event, CONVERSATION_BOT_HANDOFF)
  end

  def conversation_read(event)
    broadcast_to_inbox_members(event, CONVERSATION_READ)
  end

  def conversation_status_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, CONVERSATION_STATUS_CHANGED, conversation.push_event_data)
  end

  def conversation_updated(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, CONVERSATION_UPDATED, conversation.push_event_data)
  end

  def conversation_unread_count_changed(event)
    account, inbox_members = ::Conversations::UnreadCounts::BroadcastScope.new(event).perform
    return if account.blank? || !account.feature_enabled?('conversation_unread_counts')

    tokens = user_tokens(account, inbox_members)

    broadcast(account, tokens, CONVERSATION_UNREAD_COUNT_CHANGED, {})
  end

  def conversation_typing_on(event)
    conversation = event.data[:conversation]
    account = conversation.account
    user = event.data[:user]
    tokens = typing_event_listener_tokens(account, conversation, user)

    broadcast(
      account,
      tokens,
      CONVERSATION_TYPING_ON,
      conversation: conversation.push_event_data,
      user: user.push_event_data,
      is_private: event.data[:is_private] || false
    )
  end

  def conversation_typing_off(event)
    conversation = event.data[:conversation]
    account = conversation.account
    user = event.data[:user]
    tokens = typing_event_listener_tokens(account, conversation, user)

    broadcast(
      account,
      tokens,
      CONVERSATION_TYPING_OFF,
      conversation: conversation.push_event_data,
      user: user.push_event_data,
      is_private: event.data[:is_private] || false
    )
  end

  def assignee_changed(event)
    # Model callbacks identify automatic assignment (auto-assignment or automation
    # rules) by performed_by. The V2 AssignmentService also dispatches an event with
    # user (the assigned agent, NOT the performer). Neither requires inferring
    # automation from a missing Current.user.
    automatic_assignment = [Inbox, AssignmentPolicy, AutomationRule, AutomationWorkflow].include?(event.data[:performed_by].class) || event.data[:user].present?
    broadcast_to_inbox_members(event, ASSIGNEE_CHANGED, automatic_assignment: automatic_assignment)
  end

  def team_changed(event)
    broadcast_to_inbox_members(event, TEAM_CHANGED)
  end

  def conversation_contact_changed(event)
    broadcast_to_inbox_members(event, CONVERSATION_CONTACT_CHANGED)
  end

  def contact_created(event)
    contact, account = extract_contact_and_account(event)
    broadcast(account, [account_token(account)], CONTACT_CREATED, contact.push_event_data)
  end

  def contact_updated(event)
    contact, account = extract_contact_and_account(event)
    broadcast(account, [account_token(account)], CONTACT_UPDATED, contact.push_event_data)
  end

  def contact_merged(event)
    contact, account = extract_contact_and_account(event)
    broadcast(account, [account_token(account)], CONTACT_MERGED, contact.push_event_data)
  end

  def contact_deleted(event)
    contact_data = event.data[:contact_data]
    account = Account.find_by(id: contact_data[:account_id])
    return if account.blank?

    broadcast(account, [account_token(account)], CONTACT_DELETED, contact_data)
  end

  def conversation_mentioned(event)
    conversation, account = extract_conversation_and_account(event)
    user = event.data[:user]
    return unless can_view_conversation?(account, user, conversation)

    broadcast(account, [user.pubsub_token], CONVERSATION_MENTIONED, conversation.push_event_data)
  end

  private

  def broadcast_to_inbox_members(event, event_name, **metadata)
    conversation, account = extract_conversation_and_account(event)

    tokens = conversation_tokens(account, conversation, previous_assignee_id: event.data[:changed_attributes]&.dig('assignee_id')&.first)

    broadcast(account, tokens, event_name, conversation.push_event_data.merge(metadata))
  end

  def can_view_conversation?(account, user, conversation)
    account_user = account.account_users.find_by(user_id: user.id)
    return false if account_user.blank?

    ConversationPolicy.new({ user: user, account: account, account_user: account_user }, conversation).show?
  end

  def account_token(account)
    "account_#{account.id}"
  end

  def typing_event_listener_tokens(account, conversation, user)
    current_user_token = if user.is_a?(Contact)
                           conversation.contact_inbox.pubsub_token
                         elsif user.respond_to?(:pubsub_token)
                           user.pubsub_token
                         end

    tokens = conversation_tokens(account, conversation) + [conversation.contact_inbox.pubsub_token]
    current_user_token.present? ? tokens - [current_user_token] : tokens
  end

  # A plain agent only hears about the conversations assigned to them, plus the one that was just taken from them so
  # their screen can drop it. Administrators and agents with a custom role keep hearing about every conversation of
  # their inboxes (their role decides what the screen shows).
  def conversation_tokens(account, conversation, previous_assignee_id: nil)
    members = conversation.inbox.members
    custom_role_user_ids = AccountUser.where(account_id: account.id).where.not(custom_role_id: nil).select(:user_id)
    assigned_ids = [conversation.assignee_id, previous_assignee_id].compact
    user_tokens(account, members.where(id: custom_role_user_ids).or(members.where(id: assigned_ids)))
  end

  def user_tokens(account, agents)
    agent_tokens = agents.pluck(:pubsub_token)
    admin_tokens = account.administrators.pluck(:pubsub_token)
    (agent_tokens + admin_tokens).uniq
  end

  def contact_tokens(contact_inbox, message)
    return [] if message.private?
    return [] if message.activity?
    return [] if contact_inbox.nil?

    contact_inbox_tokens(contact_inbox)
  end

  def contact_inbox_tokens(contact_inbox)
    contact = contact_inbox.contact

    contact_inbox.hmac_verified? ? contact.contact_inboxes.where(hmac_verified: true).filter_map(&:pubsub_token) : [contact_inbox.pubsub_token]
  end

  def broadcast(account, tokens, event_name, data)
    return if tokens.blank?

    payload = data.merge(account_id: account.id)
    # So the frondend knows who performed the action.
    # Useful in cases like conversation assignment for generating a notification with assigner name.
    payload[:performer] = Current.user&.push_event_data if Current.user.present?

    ::ActionCableBroadcastJob.perform_later(tokens.uniq, event_name, payload)
  end
end

ActionCableListener.prepend_mod_with('ActionCableListener')
