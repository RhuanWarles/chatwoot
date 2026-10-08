class Evolution::GroupRequest < ApplicationRecord
  self.table_name = 'evolution_group_requests'

  belongs_to :account
  belongs_to :inbox
  belongs_to :user
  belongs_to :conversation, optional: true

  validates :request_id, :payload_digest, presence: true
end
