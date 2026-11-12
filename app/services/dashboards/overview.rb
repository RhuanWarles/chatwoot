# Everything the general dashboard shows, in one answer, for one period and (optionally) one inbox. The AI numbers come from
# the same service as the AI analytics screen, with the same period, so the two screens never disagree.
class Dashboards::Overview
  def initialize(account, params)
    @account = account
    @params = params
    @scope = Dashboards::Scope.new(account, params)
  end

  def perform
    Time.use_zone(@scope.zone) do
      {
        filters: filters,
        attendance: Dashboards::Attendance.new(@scope).perform,
        ai: ai,
        crm: Dashboards::Crm.new(@scope, @params[:pipeline_id]).perform,
        blasts: Dashboards::Blasts.new(@scope).perform,
        inboxes: @account.inboxes.order(:name).map { |inbox| { id: inbox.id, name: inbox.name } }
      }
    end
  end

  private

  def filters
    range = @scope.range
    { start_at: range.begin.iso8601, end_at: range.end.iso8601, inbox_id: @scope.inbox_id,
      timezone: @scope.zone.tzinfo.name, generated_at: Time.current.iso8601 }
  end

  def ai
    return nil unless @account.feature_enabled?('text_ai')

    data = Saas::AiAnalytics.new(@account, ai_params).perform
    { summary: data[:summary], billing: data[:billing] }
  end

  def ai_params
    { start_at: @scope.range.begin.iso8601, end_at: @scope.range.end.iso8601, inbox_id: @scope.inbox_id&.to_s }
  end
end
