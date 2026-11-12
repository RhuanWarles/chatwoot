# Broadcast ("disparos") numbers of the dashboard: what was sent in the period, how much of it arrived and how many customers
# wrote back. Only campaigns that record their recipients (the WhatsApp one-off ones) can be followed; the others have no
# recipient list to count.
class Dashboards::Blasts
  LIMIT = 5
  REPLIED = <<~SQL.squish.freeze
    EXISTS (
      SELECT 1 FROM messages replies
      JOIN conversations ON conversations.id = replies.conversation_id
      WHERE conversations.contact_id = campaign_recipients.contact_id
        AND conversations.inbox_id = campaign_recipients.inbox_id
        AND replies.message_type = 0
        AND replies.created_at > campaign_recipients.sent_at
    )
  SQL

  def initialize(scope)
    @scope = scope
  end

  def perform
    return empty unless trackable?

    sent = recipients(@scope.range)
    rows = campaigns(sent)
    {
      available: true,
      sent: sent.count,
      delivered: delivered(sent).count,
      replied: sent.where(REPLIED).count,
      previous_sent: recipients(@scope.previous_range).count,
      campaigns: rows
    }
  end

  private

  def empty
    { available: false, sent: 0, delivered: 0, replied: 0, previous_sent: 0, campaigns: [] }
  end

  def trackable?
    defined?(CampaignRecipient) && CampaignRecipient.table_exists?
  end

  def recipients(within)
    @scope.filter_inbox(CampaignRecipient.where(account_id: @scope.account.id, sent_at: within))
  end

  def delivered(relation)
    relation.where(status: CampaignRecipient.statuses.values_at('delivered', 'read'))
  end

  def campaigns(sent)
    sent_by = sent.group(:campaign_id).count
    ids = sent_by.sort_by { |_id, count| -count }.first(LIMIT).map(&:first)
    counts = { sent: sent_by, delivered: delivered(sent).group(:campaign_id).count, replied: sent.where(REPLIED).group(:campaign_id).count }
    @scope.account.campaigns.includes(:inbox).where(id: ids).sort_by { |campaign| -sent_by[campaign.id] }
          .map { |campaign| campaign_row(campaign, counts) }
  end

  def campaign_row(campaign, counts)
    { id: campaign.display_id, title: campaign.title, channel: campaign.inbox&.channel_type, sent: counts[:sent][campaign.id],
      delivered: counts[:delivered][campaign.id].to_i, replied: counts[:replied][campaign.id].to_i }
  end
end
