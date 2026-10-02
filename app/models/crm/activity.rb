class Crm::Activity < ApplicationRecord
  self.table_name = 'crm_activities'
  TYPES = %w[task call meeting follow_up].freeze
  STATUSES = %w[pending completed cancelled].freeze
  belongs_to :account
  belongs_to :deal, class_name: 'Crm::Deal'
  belongs_to :contact, optional: true
  belongs_to :owner, class_name: 'User', optional: true
  validates :activity_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :title, presence: true, length: { maximum: 255 }
  validates :due_at, presence: true
  validate :associations_belong_to_account
  before_save :set_completion_time
  after_create :record_creation
  after_update :record_change

  private

  def associations_belong_to_account
    errors.add(:deal, 'must belong to the same account') if deal && deal.account_id != account_id
    errors.add(:contact, 'must belong to the same account') if contact && contact.account_id != account_id
    errors.add(:owner, 'must belong to the same account') if owner_id && !account.users.exists?(id: owner_id)
  end

  def set_completion_time
    self.completed_at = status == 'completed' ? Time.current : nil if new_record? || will_save_change_to_status?
  end

  def record_creation
    record_event('activity_created')
  end

  def record_change
    event_type = if saved_change_to_status? && status == 'completed'
                   'activity_completed'
                 elsif saved_change_to_status? && status == 'cancelled'
                   'activity_cancelled'
                 else
                   'activity_updated'
                 end
    record_event(event_type) if saved_changes.except('updated_at').present?
  end

  def record_event(event_type)
    deal.events.create!(account_id: account_id, actor: Current.user, event_type: event_type,
                        metadata: { activity_id: id, title: title, due_at: due_at.iso8601, activity_type: activity_type })
  end
end
