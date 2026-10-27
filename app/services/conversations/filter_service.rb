class Conversations::FilterService < FilterService
  ATTRIBUTE_MODEL = 'conversation_attribute'.freeze

  def initialize(params, user, account)
    @account = account
    super(params, user)
  end

  def perform
    validate_query_operator
    @conversations = query_builder(@filters['conversations'])
    mine_count, unassigned_count, all_count, unanswered_count = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count

    {
      conversations: conversations,
      count: {
        mine_count: mine_count,
        assigned_count: assigned_count,
        unassigned_count: unassigned_count,
        all_count: all_count,
        unanswered_count: unanswered_count
      }
    }
  end

  def base_relation
    # :messages is deliberately not preloaded: the list payload fetches messages through
    # scoped queries (last message, last_non_activity_message), which bypass the preload.
    conversations = @account.conversations.includes(
      :taggings, { assignee: { avatar_attachment: [:blob] } }, { contact: { avatar_attachment: [:blob] } }, :team,
      :contact_inbox
    ).preload(
      inbox: :channel,
      ai_assignee: { avatar_attachment: [:blob] }
    )
    conversations = conversations.with_last_relevant_message_type

    Conversations::PermissionFilterService.new(
      conversations,
      @user,
      @account,
      plan_hint_selective_filter: label_filter_present?
    ).perform
  end

  def current_page
    @params[:page] || 1
  end

  def filter_config
    {
      entity: 'Conversation',
      table_name: 'conversations'
    }
  end

  def conversations
    Conversations::SortService.apply(@conversations, @params[:sort_by]).page(current_page)
  end

  private

  def build_condition_query_string(current_filter, query_hash, current_index)
    case query_hash['attribute_key']
    when 'ai_state'
      ai_state_filter_query(query_hash)
    when 'ai_agent_id'
      ai_agent_filter_query(query_hash, current_index)
    else
      super
    end
  end

  def ai_state_filter_query(query_hash)
    active_query = Conversations::AiFilterQuery.active
    is_active = Array(query_hash['values']).map(&:to_s).include?('active')
    is_active = !is_active if query_hash['filter_operator'] == 'not_equal_to'
    "#{is_active ? '' : 'NOT '} (#{active_query}) #{query_hash[:query_operator]}"
  end

  def ai_agent_filter_query(query_hash, current_index)
    @filter_values["value_#{current_index}"] = Array(query_hash['values']).map(&:to_i).map(&:to_s)
    agent_query = Conversations::AiFilterQuery.agent(":value_#{current_index}")
    suffix = " #{query_hash[:query_operator]}"
    query_hash['filter_operator'] == 'not_equal_to' ? "NOT (#{agent_query})#{suffix}" : "(#{agent_query})#{suffix}"
  end

  # The planner hint only pays off when the label condition positively narrows the
  # result set: `equal_to` joined by AND. Negative/presence operators or an OR in the
  # payload leave the result broad, where the inbox index is the better driver.
  def label_filter_present?
    payload = @params[:payload].to_a
    return false if payload.any? { |query_hash| query_hash[:query_operator].to_s.casecmp('or').zero? }

    payload.any? { |query_hash| query_hash[:attribute_key] == 'labels' && query_hash[:filter_operator] == 'equal_to' }
  end

  def set_count_for_all_conversations
    counts = @conversations.except(:includes, :order).pick(
      Arel.sql(ActiveRecord::Base.sanitize_sql_array(['COUNT(*) FILTER (WHERE assignee_id = ?)', @user.id])),
      Arel.sql('COUNT(*) FILTER (WHERE assignee_id IS NULL AND assignee_agent_bot_id IS NULL)'),
      Arel.sql('COUNT(*)'),
      Arel.sql("COUNT(*) FILTER (WHERE #{Conversation.awaiting_response_sql})")
    )
    counts || [0, 0, 0, 0]
  end
end
