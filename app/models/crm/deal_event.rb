class Crm::DealEvent < ApplicationRecord
  self.table_name = 'crm_deal_events'
  EVENT_TYPES = %w[
    deal_created stage_changed status_changed value_changed owner_changed note_created
    activity_created activity_updated activity_completed activity_cancelled meeting_scheduled meeting_rescheduled
  ].freeze
  belongs_to :account
  belongs_to :deal, class_name: 'Crm::Deal'
  belongs_to :actor, class_name: 'User', optional: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validate :belongs_to_deal_account

  private

  def belongs_to_deal_account
    errors.add(:deal, 'must belong to the same account') if deal && deal.account_id != account_id
  end
end
