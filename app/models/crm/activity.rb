class Crm::Activity < ApplicationRecord
  self.table_name = 'crm_activities'
  TYPES = %w[task call meeting follow_up].freeze
  STATUSES = %w[pending completed cancelled].freeze
  DURATION_RANGE = (1..1440).freeze
  MAX_PARTICIPANTS = 50
  ACTIVITY_FIELDS = %w[activity_type title description due_at owner_id status duration_minutes participants create_meet].freeze
  belongs_to :google_calendar_connection, class_name: 'Crm::GoogleCalendarConnection', optional: true
  belongs_to :account
  belongs_to :deal, class_name: 'Crm::Deal'
  belongs_to :contact, optional: true
  belongs_to :owner, class_name: 'User', optional: true
  validates :activity_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :title, presence: true, length: { maximum: 255 }
  validates :due_at, presence: true
  validates :duration_minutes, numericality: { only_integer: true, in: DURATION_RANGE }
  validate :valid_calendar_fields
  validate :associations_belong_to_account
  before_save :set_completion_time
  after_create :record_creation
  after_update :record_change
  after_commit :enqueue_calendar_sync, on: [:create, :update]

  def self.valid_participants?(values)
    values.is_a?(Array) && values.length <= MAX_PARTICIPANTS &&
      values.all? { |email| email.is_a?(String) && email.match?(URI::MailTo::EMAIL_REGEXP) }
  end

  private

  def valid_calendar_fields
    unless self.class.valid_participants?(participants)
      errors.add(:participants, 'must contain valid email addresses')
    end
    return unless external_provider == 'google'

    errors.add(:activity_type, 'must be a meeting') unless activity_type == 'meeting'
    if google_calendar_connection && (google_calendar_connection.account_id != account_id || google_calendar_connection.user_id != owner_id)
      errors.add(:owner, 'must match the connected calendar user')
    end
  end

  def enqueue_calendar_sync
    if external_provider == 'google' && sync_status == 'pending' && previous_changes.key?('google_sync_revision')
      Crm::GoogleCalendarSyncJob.perform_later(id, google_sync_revision)
    end
  end

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
    record_event(event_type) if ACTIVITY_FIELDS.any? { |field| saved_change_to_attribute?(field) }
  end

  def record_event(event_type)
    deal.events.create!(account_id: account_id, actor: Current.user, event_type: event_type,
                        metadata: { activity_id: id, title: title, due_at: due_at.iso8601, activity_type: activity_type })
  end
end
