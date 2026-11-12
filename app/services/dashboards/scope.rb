# What every block of the general dashboard looks at: the account, the period (and the one before it) in the account's own
# days, and the inbox filter. Each block asks it for the messages, replies and day buckets, so they all count alike.
class Dashboards::Scope
  attr_reader :account, :period, :inbox_id

  delegate :range, :previous_range, :zone, :dates, to: :period

  def initialize(account, params)
    @account = account
    @period = AnalyticsPeriod.new(account, params)
    @inbox_id = inbox_param(params[:inbox_id])
  end

  # Public messages of the conversation between the customer and the account: what a person or the AI said or heard.
  def messages(within = range)
    filter_inbox(Message.where(account_id: account.id, message_type: %i[incoming outgoing], private: false, created_at: within))
  end

  # Public replies sent to customers, by anyone (people, the AI or bots).
  def replies(within = range)
    filter_inbox(Crm::Responders.replies(account).where(created_at: within))
  end

  def conversations(within = range)
    filter_inbox(account.conversations.where(created_at: within))
  end

  def filter_inbox(relation)
    inbox_id ? relation.where(inbox_id: inbox_id) : relation
  end

  # A timestamp column as the account's wall clock (stored in UTC).
  def local(column)
    "((#{column} AT TIME ZONE 'UTC') AT TIME ZONE #{ActiveRecord::Base.connection.quote(zone.tzinfo.name)})"
  end

  def day_sql(column)
    Arel.sql("to_char(#{local(column)}, 'YYYY-MM-DD')")
  end

  private

  def inbox_param(value)
    return nil if value.blank?

    id = Integer(value.to_s, 10)
    raise ArgumentError, 'invalid_inbox_id' unless account.inboxes.exists?(id: id)

    id
  rescue ArgumentError
    raise ArgumentError, 'invalid_inbox_id'
  end
end
