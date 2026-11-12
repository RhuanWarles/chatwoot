# The customer service numbers of the dashboard. None of them depends on someone resolving a conversation: they come from
# the messages and from the events the system already records (first responses, waiting customers).
class Dashboards::Attendance
  WAITING_FRESH = 15.minutes
  WAITING_LATE = 1.hour
  AGENTS_LIMIT = 8
  WAITING_LIMIT = 5
  AI = Crm::ResponderReport::AI_SQL
  HUMAN = Crm::ResponderReport::HUMAN_SQL

  def initialize(scope)
    @scope = scope
  end

  def perform
    {
      activity: activity,
      replies: replies,
      handled: handled,
      waiting: waiting,
      first_response: first_response,
      heatmap: heatmap,
      agents: agents
    }
  end

  private

  attr_reader :scope

  # Conversations where someone said something in the period (not only the ones that began in it).
  def activity
    per_day = scope.messages.reorder(nil).group(scope.day_sql('messages.created_at')).distinct.count(:conversation_id)
    {
      conversations: scope.messages.distinct.count(:conversation_id),
      previous: scope.messages(scope.previous_range).distinct.count(:conversation_id),
      per_day: scope.dates.map { |date| { date: date.iso8601, conversations: per_day[date.iso8601].to_i } }
    }
  end

  # Replies per day, by who wrote them. A reply that is neither from a person nor from the AI/bots (an automation) is not counted.
  def replies
    per_day = scope.dates.to_h { |date| [date.iso8601, { date: date.iso8601, ai: 0, people: 0 }] }
    reply_counts.each { |(day, side), count| per_day[day][side] += count if per_day[day] }
    ai = per_day.values.sum { |row| row[:ai] }
    people = per_day.values.sum { |row| row[:people] }
    { per_day: per_day.values, ai: ai, people: people, ai_share: share(ai, ai + people) }
  end

  def reply_counts
    grouped = scope.replies.reorder(nil).group(scope.day_sql('messages.created_at'), Arel.sql(AI), Arel.sql(HUMAN)).count
    grouped.each_with_object(Hash.new(0)) do |((day, ai, human), count), totals|
      side = ai ? :ai : (:people if human)
      totals[[day, side]] += count if side
    end
  end

  # Of the conversations that got a reply, how many were answered only by the AI.
  def handled
    rows = scope.replies.reorder(nil).group(:conversation_id)
                .pluck(Arel.sql('messages.conversation_id'), Arel.sql("BOOL_OR(#{AI})"), Arel.sql("BOOL_OR(#{HUMAN})"))
    ai_only = rows.count { |_id, ai, human| ai && !human }
    { responded: rows.length, ai_only: ai_only, ai_only_share: share(ai_only, rows.length) }
  end

  # Customers who wrote and got no answer yet (from a person or from the AI): right now, not in the period.
  def waiting_scope
    @waiting_scope ||= scope.filter_inbox(scope.account.conversations.where.not(waiting_since: nil).where(status: %i[open pending]))
  end

  def waiting
    now = Time.current
    since = waiting_scope.pluck(:waiting_since)
    ages = since.map { |time| now - time }
    {
      total: since.length,
      fresh: ages.count { |age| age < WAITING_FRESH },
      middle: ages.count { |age| age >= WAITING_FRESH && age < WAITING_LATE },
      late: ages.count { |age| age >= WAITING_LATE },
      oldest_minutes: ages.empty? ? nil : (ages.max / 60).floor,
      list: waiting_list(now)
    }
  end

  def waiting_list(now)
    waiting_scope.includes(:contact, :inbox, :assignee).order(:waiting_since).limit(WAITING_LIMIT).map do |conversation|
      { id: conversation.display_id, contact: conversation.contact&.name, inbox: conversation.inbox&.name,
        assignee: conversation.assignee&.name, minutes: ((now - conversation.waiting_since) / 60).floor }
    end
  end

  def first_response_events(within = scope.range)
    scope.filter_inbox(ReportingEvent.where(account_id: scope.account.id, name: 'first_response', created_at: within))
  end

  def first_response
    events = first_response_events
    per_day = events.reorder(nil).group(scope.day_sql('reporting_events.created_at')).average(:value)
    {
      average: events.average(:value)&.to_f,
      median: events.pick(Arel.sql('percentile_cont(0.5) WITHIN GROUP (ORDER BY reporting_events.value)'))&.to_f,
      previous_average: first_response_events(scope.previous_range).average(:value)&.to_f,
      count: events.count,
      per_day: scope.dates.map { |date| { date: date.iso8601, average: per_day[date.iso8601]&.to_f } }
    }
  end

  # New conversations by weekday (Monday first) and hour of the account's clock.
  def heatmap
    day = Arel.sql("EXTRACT(ISODOW FROM #{scope.local('conversations.created_at')})::int")
    hour = Arel.sql("EXTRACT(HOUR FROM #{scope.local('conversations.created_at')})::int")
    counts = scope.conversations.reorder(nil).group(day, hour).count
    (1..7).map { |weekday| (0..23).map { |hour_of_day| counts[[weekday, hour_of_day]].to_i } }
  end

  def agents
    humans = Crm::Responders.by_humans(scope.replies).reorder(nil)
    replies = humans.group(:sender_id).count
    ids = replies.sort_by { |_id, count| -count }.first(AGENTS_LIMIT).map(&:first)
    figures = agent_figures(humans, ids)
    ids.map do |id|
      { id: id, name: figures[:names][id], replies: replies[id], conversations: figures[:conversations][id].to_i,
        first_response: figures[:first][id]&.to_f, waiting: figures[:waiting][id].to_i }
    end
  end

  def agent_figures(humans, ids)
    {
      names: scope.account.users.where(id: ids).pluck(:id, :name).to_h,
      conversations: humans.group(:sender_id).distinct.count(:conversation_id),
      first: first_response_events.where.not(user_id: nil).group(:user_id).average(:value),
      waiting: waiting_scope.where.not(assignee_id: nil).group(:assignee_id).count
    }
  end

  def share(part, whole)
    whole.zero? ? nil : ((part.to_f / whole) * 100).round(2)
  end
end
