# == Schema Information
#
# Table name: account_users
#
#  id                       :bigint           not null, primary key
#  active_at                :datetime
#  auto_offline             :boolean          default(TRUE), not null
#  availability             :integer          default("online"), not null
#  role                     :integer          default("agent")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint
#  agent_capacity_policy_id :bigint
#  allowed_screens          :string           is an Array
#  custom_role_id           :bigint
#  inviter_id               :bigint
#  user_id                  :bigint
#
# Indexes
#
#  index_account_users_on_account_id                (account_id)
#  index_account_users_on_agent_capacity_policy_id  (agent_capacity_policy_id)
#  index_account_users_on_custom_role_id            (custom_role_id)
#  index_account_users_on_user_id                   (user_id)
#  uniq_user_id_per_account_id                      (account_id,user_id) UNIQUE
#

class AccountUser < ApplicationRecord
  include AvailabilityStatusable

  belongs_to :account
  belongs_to :user
  belongs_to :inviter, class_name: 'User', optional: true

  # Sections of the dashboard that can be switched off for a person; administrators always see everything.
  SCREENS = %w[inbox conversations calls contacts companies crm help_center].freeze

  enum role: { agent: 0, administrator: 1 }
  enum availability: { online: 0, offline: 1, busy: 2 }

  accepts_nested_attributes_for :account

  validate :allowed_screens_are_known

  after_create_commit :notify_creation, :create_notification_setting
  after_destroy :notify_deletion, :remove_user_from_account
  after_save :update_presence_in_redis, if: :saved_change_to_availability?
  after_commit :invalidate_filtered_unread_count_visibility, on: [:create, :destroy]
  after_update_commit :invalidate_filtered_unread_count_visibility_update, if: :filtered_unread_count_visibility_changed?

  validates :user_id, uniqueness: { scope: :account_id }

  def create_notification_setting
    setting = user.notification_settings.new(account_id: account.id)
    setting.selected_email_flags = [:email_conversation_assignment]
    setting.selected_push_flags = [:push_conversation_assignment]
    setting.save!
  end

  def remove_user_from_account
    ::Agents::DestroyJob.perform_later(account, user)
  end

  def permissions
    administrator? ? ['administrator'] : ['agent']
  end

  # A plain agent (no custom role) only sees the conversations assigned to them and the CRM cards they own.
  # Administrators and agents with a custom role keep the access their role grants.
  def own_records_only?
    agent? && custom_role_id.blank?
  end

  # nil = every screen. An empty list is stored as nil, because it would leave the person with nothing to open.
  def allowed_screens=(screens)
    super(screens.nil? ? nil : Array(screens).map(&:to_s).compact_blank.uniq.presence)
  end

  def push_event_data
    {
      id: id,
      availability: availability,
      role: role,
      user_id: user_id
    }
  end

  private

  def allowed_screens_are_known
    return if allowed_screens.blank?

    unknown = allowed_screens - SCREENS
    errors.add(:allowed_screens, "unknown screens: #{unknown.join(', ')}") if unknown.any?
  end

  def notify_creation
    Rails.configuration.dispatcher.dispatch(AGENT_ADDED, Time.zone.now, account: account)
  end

  def notify_deletion
    Rails.configuration.dispatcher.dispatch(AGENT_REMOVED, Time.zone.now, account: account)
  end

  def update_presence_in_redis
    OnlineStatusTracker.set_status(account.id, user.id, availability)
  end

  def filtered_unread_count_visibility_changed?
    previous_changes.key?('role') || previous_changes.key?('custom_role_id')
  end

  def invalidate_filtered_unread_count_visibility
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account).user_visibility_changed!(user_id: user_id)
  end

  def invalidate_filtered_unread_count_visibility_update
    dispatch_account_cache_invalidated if invalidate_filtered_unread_count_visibility
  end

  def dispatch_account_cache_invalidated
    Rails.configuration.dispatcher.dispatch(ACCOUNT_CACHE_INVALIDATED, Time.zone.now, account: account, cache_keys: account.cache_keys)
  end
end

AccountUser.prepend_mod_with('AccountUser')
AccountUser.include_mod_with('Audit::AccountUser')
AccountUser.include_mod_with('Concerns::AccountUser')
