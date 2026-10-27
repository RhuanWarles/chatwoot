# Month by month, how many public replies came from the AI and how many from people, so the operation can see how much
# of the service the AI is taking over. The filters work like the ones of the deals Kanban: they choose the customers
# (by deal owner and segment) and the conversations (answered by any of the chosen people or the AI) that are counted.
class Crm::ResponderReport
  DEFAULT_MONTHS = 6
  MAX_MONTHS = 24
  NONE = 'none'.freeze
  AI = 'ai'.freeze
  AI_SQL = "(#{Crm::Responders::AI_CONDITION})".freeze
  HUMAN_SQL = "(messages.sender_type = 'User' AND NOT #{AI_SQL})".freeze
  MONTH_SQL = "to_char(messages.created_at, 'YYYY-MM')".freeze

  def initialize(account, params)
    @account = account
    @months = months_param(params[:months])
    @owner_ids = list_param(params[:owner_ids], :owner_ids)
    @segment_ids = list_param(params[:segment_ids], :segment_ids)
    @answered_by = list_param(params[:answered_by], :answered_by, extra: [AI])
  end

  def perform
    months = monthly_rows
    {
      filters: { months: @months, owner_ids: @owner_ids, segment_ids: @segment_ids, answered_by: @answered_by },
      months: months,
      totals: totals(months),
      people: @account.users.order(:name).map { |user| { id: user.id, name: user.name } },
      segments: @account.crm_segments.order(:position, :id).map { |segment| { id: segment.id, name: segment.name } }
    }
  end

  private

  def months_param(value)
    return DEFAULT_MONTHS if value.blank?

    months = Integer(value, 10)
    raise ArgumentError, 'invalid_months' unless months.between?(1, MAX_MONTHS)

    months
  rescue ArgumentError, TypeError
    raise ArgumentError, 'invalid_months'
  end

  # Each value is an id, 'none' (nothing chosen) or, for answered_by, 'ai'.
  def list_param(value, name, extra: [])
    Array(value).map(&:to_s).compact_blank.uniq.each do |item|
      next if item == NONE && name != :answered_by
      next if extra.include?(item)

      Integer(item, 10)
    end
  rescue ArgumentError
    raise ArgumentError, "invalid_#{name}"
  end

  def first_day
    Time.current.beginning_of_month - (@months - 1).months
  end

  def month_labels
    (0...@months).map { |offset| (first_day + offset.months).strftime('%Y-%m') }
  end

  def replies
    scope = Crm::Responders.replies(@account).where(created_at: first_day..Time.current.end_of_month)
    scope = scope.where(conversation_id: deal_conversations) if @owner_ids.any? || @segment_ids.any?
    scope = answered_by_any(scope) if @answered_by.any?
    scope
  end

  def deal_conversations
    deals = nullable_filter(@account.crm_deals, :owner_id, @owner_ids)
    deals = nullable_filter(deals, :segment_id, @segment_ids)
    Conversation.where(account_id: @account.id, contact_id: deals.select(:contact_id)).select(:id)
  end

  def nullable_filter(scope, column, values)
    return scope if values.empty?

    chosen = scope.where(column => values.grep_v(NONE).map(&:to_i))
    values.include?(NONE) ? chosen.or(scope.where(column => nil)) : chosen
  end

  # A conversation counts when any of the chosen people, or the AI, ever replied in it.
  def answered_by_any(scope)
    everything = Crm::Responders.replies(@account)
    user_ids = @answered_by.grep_v(AI).map(&:to_i)
    matches = []
    matches << scope.where(conversation_id: Crm::Responders.by_ai(everything).select(:conversation_id)) if @answered_by.include?(AI)
    if user_ids.any?
      matches << scope.where(conversation_id: Crm::Responders.by_humans(everything).where(sender_id: user_ids).select(:conversation_id))
    end
    matches.reduce { |combined, match| combined.or(match) }
  end

  def counts
    replies.reorder(nil).group(Arel.sql(MONTH_SQL), :conversation_id, Arel.sql(AI_SQL), Arel.sql(HUMAN_SQL)).count
  end

  def monthly_rows
    by_month = Hash.new { |hash, month| hash[month] = { ai: 0, human: 0, conversations: {} } }
    counts.each do |(month, conversation_id, ai, human), count|
      entry = by_month[month]
      side = ai ? :ai : (:human if human)
      next unless side

      entry[side] += count
      (entry[:conversations][conversation_id] ||= Set.new) << side
    end
    month_labels.map { |month| month_row(month, by_month.fetch(month, nil)) }
  end

  def month_row(month, entry)
    ai = entry ? entry[:ai] : 0
    human = entry ? entry[:human] : 0
    kinds = entry ? entry[:conversations].values : []
    ai_only = kinds.count { |sides| sides == Set[:ai] }
    human_only = kinds.count { |sides| sides == Set[:human] }
    {
      month: month, ai_replies: ai, human_replies: human, ai_share: share(ai, ai + human),
      conversations: { total: kinds.length, ai_only: ai_only, human_only: human_only, mixed: kinds.length - ai_only - human_only },
      ai_only_share: share(ai_only, kinds.length)
    }
  end

  def totals(months)
    ai = months.sum { |row| row[:ai_replies] }
    human = months.sum { |row| row[:human_replies] }
    total = months.sum { |row| row[:conversations][:total] }
    ai_only = months.sum { |row| row[:conversations][:ai_only] }
    { ai_replies: ai, human_replies: human, ai_share: share(ai, ai + human), conversations: total, ai_only_share: share(ai_only, total) }
  end

  def share(part, whole)
    return 0.0 if whole.zero?

    ((part.to_f / whole) * 100).round(2)
  end
end
