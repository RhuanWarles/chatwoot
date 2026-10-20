class WhatsappConnection < ApplicationRecord
  STATUSES = %w[connected connecting disconnected error].freeze

  belongs_to :account
  belongs_to :inbox, optional: true

  validates :display_name, presence: true, length: { maximum: 100 }
  validates :instance_name, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :inbox_id, uniqueness: true, allow_nil: true
end
