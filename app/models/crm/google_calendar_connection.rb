class Crm::GoogleCalendarConnection < ApplicationRecord
  self.table_name = 'crm_google_calendar_connections'
  belongs_to :account
  belongs_to :user
  has_many :activities, class_name: 'Crm::Activity', dependent: :nullify
  encrypts :access_token, :refresh_token
  validates :user_id, uniqueness: { scope: :account_id }
  validates :access_token, :refresh_token, :expires_at, presence: true
  validate :user_belongs_to_account

  private

  def user_belongs_to_account
    errors.add(:user, 'must belong to the same account') unless account.users.exists?(id: user_id)
  end
end
