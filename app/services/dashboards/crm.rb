# The sales side of the dashboard. The outcome of a lead is the deal (won, lost, in which stage), a thing the team already
# does as part of the work, not a conversation someone has to remember to resolve.
class Dashboards::Crm
  LOST_REASONS_LIMIT = 5

  def initialize(scope, pipeline_id)
    @scope = scope
    @account = scope.account
    @pipeline_id = pipeline_id.to_s
  end

  def perform
    pipelines = @account.crm_pipelines.where(active: true).order(:id).to_a
    pipeline = pipelines.find { |item| item.id.to_s == @pipeline_id } || pipelines.first
    { pipelines: pipelines.map { |item| { id: item.id, name: item.name } }, pipeline_id: pipeline&.id }.merge(pipeline ? details(pipeline) : {})
  end

  private

  def details(pipeline)
    won = closed_deals(pipeline, 'won')
    lost = closed_deals(pipeline, 'lost')
    { funnel: funnel(pipeline), open_value: open_deals(pipeline).sum(:value).to_f,
      won: summary(won), lost: summary(lost), win_rate: win_rate(won.count, lost.count), lost_reasons: lost_reasons(lost) }
  end

  def open_deals(pipeline)
    pipeline.deals.where(status: 'open')
  end

  def funnel(pipeline)
    counts = open_deals(pipeline).group(:pipeline_stage_id).count
    values = open_deals(pipeline).group(:pipeline_stage_id).sum(:value)
    pipeline.stages.order(:position, :id).map do |stage|
      { id: stage.id, name: stage.name, deals: counts[stage.id].to_i, value: values[stage.id].to_f }
    end
  end

  # Deals that changed to won/lost during the period, counted once each.
  def closed_deals(pipeline, status)
    ids = Crm::DealEvent.where(account_id: @account.id, event_type: 'status_changed', created_at: @scope.range)
                        .where("metadata ->> 'to' = ?", status).select(:deal_id)
    pipeline.deals.where(id: ids, status: status)
  end

  def summary(deals)
    { deals: deals.count, value: deals.sum(:value).to_f }
  end

  def win_rate(won, lost)
    (won + lost).zero? ? nil : ((won.to_f / (won + lost)) * 100).round(2)
  end

  def lost_reasons(deals)
    counts = deals.group(:lost_reason_id).count
    names = @account.crm_lost_reasons.where(id: counts.keys.compact).pluck(:id, :name).to_h
    counts.map { |id, count| { id: id, name: names[id], deals: count } }
          .sort_by { |item| -item[:deals] }.first(LOST_REASONS_LIMIT)
  end
end
