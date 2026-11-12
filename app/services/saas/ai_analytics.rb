class Saas::AiAnalytics
  UNANSWERED_LIMIT = 5

  def initialize(account, params)
    @account = account
    @params = params
    @agent_id = scoped_id(:ai_agent_id, @account.saas_ai_agents)
    @inbox_id = scoped_id(:inbox_id, @account.inboxes)
    @period = AnalyticsPeriod.new(account, params)
    @range = @period.range
  end

  # Days are the account's days (the time zone of its reports), the same as in the general dashboard.
  def perform
    Time.use_zone(@period.zone) { build }
  end

  private

  def build
    messages = ai_messages
    conversations = messages.distinct.pluck(:conversation_id)
    usage = runtime_usage
    tools = tool_executions
    retrievals = knowledge_retrievals
    handoffs = handoff_count(conversations)

    {
      filters: { start_at: @range.begin.iso8601, end_at: @range.end.iso8601, agent_id: @agent_id, inbox_id: @inbox_id,
                 timezone: @period.zone.tzinfo.name },
      billing: billing_data(usage),
      summary: {
        conversations: conversations.length,
        turns: turn_count(messages),
        messages: messages.count,
        other_bot_messages: other_bot_messages,
        handoffs: handoffs,
        handoff_rate: percentage(handoffs, conversations.length),
        average_response_ms: nil
      },
      timeseries: timeseries(messages, usage),
      tools: tool_data(tools),
      knowledge: knowledge_data(retrievals),
      agents: @account.saas_ai_agents.order(:name).map { |agent| { id: agent.id, name: agent.name } },
      inboxes: @account.inboxes.order(:name).map { |inbox| { id: inbox.id, name: inbox.name } }
    }
  end

  def scoped_id(key, relation)
    value = @params[key].presence
    return nil if value.blank?

    id = Integer(value, 10)
    raise ArgumentError, "invalid_#{key}" unless relation.where(id: id).exists?

    id
  rescue ArgumentError
    raise ArgumentError, "invalid_#{key}"
  end

  def ai_messages
    scope = Message.where(account_id: @account.id, message_type: :outgoing, created_at: @range)
                   .where("(content_attributes #>> '{}')::json ->> 'generated_by_ai' = 'true'")
    scope = scope.where(inbox_id: @inbox_id) if @inbox_id
    scope = scope.where("(content_attributes #>> '{}')::json ->> 'ai_agent_id' = ?", @agent_id.to_s) if @agent_id
    scope.reorder(nil)
  end

  # Public replies sent by bots that are not AI agents of this platform (no generated_by_ai flag). They are not in
  # "messages" above, but the AI vs people report counts them as AI, which is one reason the two numbers can differ.
  # Not attributable to an AI agent, so there is no number when one is chosen.
  def other_bot_messages
    return nil if @agent_id

    scope = Message.where(account_id: @account.id, message_type: :outgoing, private: false, created_at: @range)
                   .where(Crm::Responders::AI_CONDITION)
                   .where("COALESCE((content_attributes #>> '{}')::json ->> 'generated_by_ai', '') <> 'true'")
    scope = scope.where(inbox_id: @inbox_id) if @inbox_id
    scope.reorder(nil).count
  end

  def runtime_usage
    scope = @account.saas_usage_records.where(source: 'runtime', kind: 'consumption', status: 'settled', created_at: @range)
    scope = scope.where("(metadata ->> 'conversation_id')::bigint IN (?)", ai_messages.select(:conversation_id))
    scope = scope.where("(metadata ->> 'conversation_id')::bigint IN (?)", Conversation.where(inbox_id: @inbox_id).select(:id)) if @inbox_id
    scope = scope.where("metadata ->> 'ai_agent_id' = ?", @agent_id.to_s) if @agent_id
    scope.joins(:wallet).where(saas_wallets: { resource: 'text_credits' })
  end

  def tool_executions
    scope = @account.saas_ai_tool_executions.where.not(conversation_id: nil).where(playground_session_id: nil).where(created_at: @range)
    scope = scope.where(ai_agent_id: @agent_id) if @agent_id
    scope = scope.joins(:conversation).where(conversations: { inbox_id: @inbox_id }) if @inbox_id
    scope
  end

  def knowledge_retrievals
    scope = @account.saas_usage_records.where(source: 'knowledge_retrieval', created_at: @range)
    scope = scope.where("(metadata ->> 'conversation_id')::bigint IN (?)", ai_messages.select(:conversation_id))
    scope = scope.where("(metadata ->> 'conversation_id')::bigint IN (?)", Conversation.where(inbox_id: @inbox_id).select(:id)) if @inbox_id
    scope = scope.where("metadata ->> 'ai_agent_id' = ?", @agent_id.to_s) if @agent_id
    scope
  end

  def handoff_count(conversation_ids)
    return 0 if conversation_ids.empty?

    @account.reporting_events.where(name: 'conversation_bot_handoff', conversation_id: conversation_ids,
                                    created_at: @range).distinct.count(:conversation_id)
  end

  def turn_count(messages)
    messages.distinct.count("COALESCE((content_attributes #>> '{}')::json ->> 'ai_response_batch_id', id::text)")
  end

  def tool_data(scope)
    rows = scope.group(:ai_tool_id).count
    success = scope.where(status: 'completed').group(:ai_tool_id).count
    tools = @account.saas_ai_tools.where(id: rows.keys).index_by(&:id)
    items = rows.map do |id, executions|
      completed = success[id].to_i
      { id: id, name: tools[id]&.name, executions: executions, success: completed, failures: executions - completed,
        success_rate: percentage(completed, executions) }
    end.sort_by { |item| -item[:executions] }
    { executions: scope.count, success: scope.where(status: 'completed').count, failures: scope.where(status: 'failed').count,
      success_rate: percentage(scope.where(status: 'completed').count, scope.count), top: items }
  end

  def knowledge_data(scope)
    accepted = scope.where("COALESCE(NULLIF(metadata -> 'retrieval' ->> 'accepted_count', ''), '0')::integer > 0")
    conversations = accepted.distinct.count("metadata ->> 'conversation_id'")
    { queries: scope.count, hits: accepted.count, hit_rate: percentage(accepted.count, scope.count),
      conversations: conversations, utilization_rate: percentage(conversations, ai_messages.distinct.count(:conversation_id)),
      unanswered: unanswered_queries(scope) }
  end

  # The questions that found nothing in the knowledge base, most frequent first. The text is already kept with each query.
  def unanswered_queries(scope)
    scope.where("COALESCE(NULLIF(metadata -> 'retrieval' ->> 'accepted_count', ''), '0')::integer = 0")
         .where("COALESCE(metadata -> 'retrieval' ->> 'query', '') <> ''")
         .group("metadata -> 'retrieval' ->> 'query'").reorder(Arel.sql('COUNT(*) DESC')).limit(UNANSWERED_LIMIT).count
         .map { |query, count| { query: query.first(300), count: count } }
  end

  def billing_data(scope)
    wallet = @account.saas_wallets.find_by(resource: 'text_credits')
    mode = @account.saas_ai_setting&.text_mode || 'platform'
    tokens = Saas::AiTokenUsage.new(ai_messages).perform
    return tokens.merge(mode: mode, estimated_cost_usd: nil, average_cost_per_conversation: nil) unless mode == 'platform'

    average_credits = average(scope.sum(:units), ai_messages.distinct.count(:conversation_id))
    tokens.merge(mode: mode, credits_consumed: scope.sum(:units), credits_available: wallet ? wallet.available_units : 0,
                 average_credits_per_conversation: average_credits)
  end

  def timeseries(messages, usage)
    buckets = {}
    conversations = Hash.new { |hash, key| hash[key] = [] }
    turns = Hash.new { |hash, key| hash[key] = [] }
    tokens = Hash.new(0)
    messages.pluck(:created_at, :conversation_id, :id, :content_attributes).each do |time, conversation_id, id, attributes|
      date = time.in_time_zone.to_date.iso8601
      turn_id = attributes['ai_response_batch_id'] || id
      tokens[date] += attributes['ai_token_usage'].to_h['total_tokens'].to_i unless turns[date].include?(turn_id)
      turns[date] << turn_id
      buckets[date] = (buckets[date] || 0) + 1
      conversations[date] << conversation_id unless conversations[date].include?(conversation_id)
    end
    usage.group_by { |record| record.created_at.in_time_zone.to_date.iso8601 }.each_with_object([]) do |(date, records), result|
      result << { date: date, conversations: 0, messages: 0, credits: records.sum(&:units) }
    end.tap do |result|
      buckets.each do |date, count|
        item = result.find { |entry| entry[:date] == date } || result.push({ date: date, conversations: 0, messages: 0, credits: 0 }).last
        item[:messages] = count
        item[:conversations] = conversations[date].length
        item[:turns] = turns[date].uniq.length
      end
      (@range.begin.to_date..@range.end.to_date).each do |day|
        date = day.iso8601
        result << { date: date, conversations: 0, messages: 0, credits: 0 } unless result.any? { |item| item[:date] == date }
      end
      result.each do |item|
        item[:turns] ||= 0
        item[:tokens] = tokens[item[:date]]
      end
      result.sort_by! { |entry| entry[:date] }
    end
  end

  def percentage(numerator, denominator)
    return 0.0 if denominator.to_i.zero?

    ((numerator.to_f / denominator) * 100).round(2)
  end

  def average(total, count)
    return nil if count.to_i.zero?

    (total.to_f / count).round(4)
  end
end
