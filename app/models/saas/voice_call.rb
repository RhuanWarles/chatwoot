class Saas::VoiceCall < ApplicationRecord
  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :usage_record, class_name: 'Saas::UsageRecord'

  validates :request_id, presence: true, uniqueness: { scope: :account_id }
  validates :provider_call_id, uniqueness: true, allow_nil: true
  validates :direction, inclusion: { in: %w[inbound outbound] }
  validates :status, inclusion: { in: %w[pending submitting queued ringing in-progress ended failed unknown] }
  validates :customer_number, :assistant_id, :phone_number_id, presence: true

  def public_data
    attributes.slice('id', 'contact_id', 'direction', 'status', 'customer_number', 'duration_seconds',
                     'max_duration_seconds', 'ended_reason', 'summary', 'created_at').merge(billed_seconds: usage_record.units)
  end
end
