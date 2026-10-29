class AutomationExecution < ApplicationRecord
  STATUSES = %w[started running success partial_success failed partial skipped].freeze

  belongs_to :account
  belongs_to :automation_rule
  belongs_to :conversation, optional: true
  belongs_to :contact, optional: true
  belongs_to :deal, class_name: 'Crm::Deal', foreign_key: :crm_deal_id, optional: true

  validates :action_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, uniqueness: true, allow_nil: true
end
