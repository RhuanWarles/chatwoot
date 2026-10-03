class Crm::GoogleCalendarSyncJob < ApplicationJob
  queue_as :default
  MAX_CONFERENCE_POLLS = 6
  CONFERENCE_POLL_INTERVAL = 10.seconds

  def perform(activity_id, revision, poll = 0)
    activity = Crm::Activity.find_by(id: activity_id)
    return unless activity

    activity.with_lock do
      return unless activity.external_provider == 'google' && activity.sync_status == 'pending' && activity.google_sync_revision == revision

      result = Crm::GoogleCalendarSyncService.new(activity).perform(polling: poll.positive?)
      if result == :pending
        raise CustomExceptions::CrmCalendar, 'google_meet_pending' if poll >= MAX_CONFERENCE_POLLS

        self.class.set(wait: CONFERENCE_POLL_INTERVAL).perform_later(activity.id, revision, poll + 1)
      end
    rescue CustomExceptions::CrmCalendar => error
      activity.update_columns(sync_status: 'failed', sync_error: error.message)
    end
  end
end
