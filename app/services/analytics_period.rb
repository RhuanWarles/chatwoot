# The period an analytics screen looks at, in the account's own days: the time zone chosen for the reports of the
# account (UTC when it has none), so "today" and every bar of a chart start at the midnight the team lives by and not at
# 21:00 of the day before. The AI analytics, the AI vs people report and the general dashboard all read it from here, so
# that they count the same days and the same numbers can be compared between them.
class AnalyticsPeriod
  PRESET_DAYS = { '7d' => 7, '30d' => 30 }.freeze
  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

  attr_reader :zone, :range

  def self.zone_for(account)
    ActiveSupport::TimeZone[account.reporting_timezone.to_s] || ActiveSupport::TimeZone['UTC']
  end

  def initialize(account, params)
    @zone = self.class.zone_for(account)
    @params = params
    @range = Time.use_zone(@zone) { build_range }
  rescue ArgumentError, TypeError
    raise ArgumentError, 'invalid_period'
  end

  # The same length right before the period, to say whether a number went up or down.
  def previous_range
    (range.begin - (range.end - range.begin))...range.begin
  end

  # Each day of the period, in the account's time zone.
  def dates
    Time.use_zone(zone) { (range.begin.to_date..range.end.to_date).to_a }
  end

  private

  def build_range
    now = Time.current
    start_at = custom_time(:start_date, :beginning_of_day) || custom_time(:start_at) || preset_start(now)
    end_at = custom_time(:end_date, :end_of_day) || custom_time(:end_at) || now
    raise ArgumentError, 'invalid_period' if start_at >= end_at

    start_at..end_at
  end

  # "Last 7 days" is today and the 6 before it, from midnight: the first bar is a whole day, not the second half of one.
  def preset_start(now)
    case @params[:period].to_s
    when 'today' then now.beginning_of_day
    when 'month' then now.beginning_of_month
    else (PRESET_DAYS.fetch(@params[:period].to_s, 7) - 1).days.ago.beginning_of_day
    end
  end

  # `*_date` is a day ("2026-11-01") in the account's time zone; `*_at` is an exact moment.
  def custom_time(key, edge = nil)
    value = @params[key].presence
    return nil unless value

    value = value.to_s
    raise ArgumentError, 'invalid_period' if edge && !DATE_FORMAT.match?(value)

    time = Time.zone.parse(value)
    raise ArgumentError, 'invalid_period' if time.nil?

    edge ? time.public_send(edge) : time
  end
end
