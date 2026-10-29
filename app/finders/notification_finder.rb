class NotificationFinder
  attr_reader :current_user, :current_account, :params

  RESULTS_PER_PAGE = 15

  def initialize(current_user, current_account, params = {})
    @current_user = current_user
    @current_account = current_account
    @params = params
    set_up
  end

  def notifications
    @notifications.page(current_page).per(RESULTS_PER_PAGE).order(last_activity_at: sort_order)
  end

  def unread_count
    if type_included?('read')
      # If we're including read notifications, filter to unread
      @notifications.where(read_at: nil).count
    else
      # Already filtered to unread notifications, just count
      @notifications.count
    end
  end

  def count
    @notifications.count
  end

  private

  def set_up
    find_all_notifications
    filter_snoozed_notifications
    filter_read_notifications
  end

  def find_all_notifications
    @notifications = current_user.notifications.where(account_id: @current_account.id)
    @notifications = only_own_conversations(@notifications) if own_records_only?
  end

  # Notifications that were created before the agent lost access to a conversation must not keep exposing it.
  def only_own_conversations(notifications)
    own_conversations = @current_account.conversations.where(assignee_id: current_user.id).select(:id)
    own_messages = @current_account.messages.where(conversation_id: own_conversations).select(:id)
    notifications.where(primary_actor_type: 'Conversation', primary_actor_id: own_conversations)
                 .or(notifications.where(primary_actor_type: 'Message', primary_actor_id: own_messages))
                 .or(notifications.where.not(primary_actor_type: %w[Conversation Message]))
  end

  def own_records_only?
    @current_account.account_users.find_by(user_id: current_user.id)&.own_records_only?
  end

  def filter_snoozed_notifications
    @notifications = @notifications.where(snoozed_until: nil) unless type_included?('snoozed')
  end

  def filter_read_notifications
    @notifications = @notifications.where(read_at: nil) unless type_included?('read')
  end

  def type_included?(type)
    (params[:includes] || []).include?(type)
  end

  def current_page
    params[:page] || 1
  end

  def sort_order
    params[:sort_order] || :desc
  end
end
