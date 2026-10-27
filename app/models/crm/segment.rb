class Crm::Segment < ApplicationRecord
  self.table_name = 'crm_segments'
  COLOR_FORMAT = /\A#\h{6}\z/

  belongs_to :account
  has_many :deals, class_name: 'Crm::Deal', foreign_key: :segment_id, inverse_of: :segment, dependent: :nullify

  normalizes :name, with: ->(value) { value.strip }
  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :color, format: { with: COLOR_FORMAT }, allow_blank: true

  scope :active, -> { where(active: true) }
end
