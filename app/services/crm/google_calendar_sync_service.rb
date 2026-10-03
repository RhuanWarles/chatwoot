class Crm::GoogleCalendarSyncService
  def initialize(activity)
    @activity = activity
  end

  def perform(polling: false)
    connection = @activity.google_calendar_connection
    unless connection && connection.account_id == @activity.account_id && connection.provider_uid == @activity.google_account_uid &&
           connection.account.users.exists?(id: connection.user_id)
      raise CustomExceptions::CrmCalendar, 'google_disconnected'
    end
    client = Crm::GoogleCalendarClient.new(connection)
    if @activity.status == 'cancelled'
      client.delete(@activity.google_event_id)
      @activity.update_columns(sync_status: 'synced', sync_error: nil, synced_at: Time.current)
      return
    end
    existing = client.event(@activity.google_event_id)
    event = if polling && existing
              existing
            else
              existing ? client.update(@activity.google_event_id, event_payload) : client.insert(event_payload.merge(id: @activity.google_event_id))
            end
    raise CustomExceptions::CrmCalendar, 'google_event_cancelled' if event['status'] == 'cancelled'

    conference = event.dig('conferenceData', 'createRequest', 'status', 'statusCode')
    video = event.dig('conferenceData', 'entryPoints')&.find { |entry| entry['entryPointType'] == 'video' }
    meeting_url = event['hangoutLink'] || video&.fetch('uri')
    @activity.update_columns(google_event_url: event['htmlLink'], meeting_url: meeting_url)
    if @activity.create_meet && !meeting_url
      if conference == 'failure'
        @activity.update_columns(google_meet_request_id: SecureRandom.uuid)
        raise CustomExceptions::CrmCalendar, 'google_meet_failed'
      end
      return :pending
    end
    event_type = @activity.synced_at ? 'meeting_rescheduled' : 'meeting_scheduled'
    @activity.update_columns(sync_status: 'synced', sync_error: nil, synced_at: Time.current)
    @activity.deal.events.create!(account_id: @activity.account_id, actor_id: connection.user_id, event_type: event_type,
                                 metadata: { activity_id: @activity.id, title: @activity.title, due_at: @activity.due_at.iso8601,
                                             duration_minutes: @activity.duration_minutes, meeting_url: meeting_url })
    :synced
  end

  private

  def event_payload
    payload = {
      summary: @activity.title, description: @activity.description,
      start: { dateTime: @activity.due_at.iso8601 },
      end: { dateTime: (@activity.due_at + @activity.duration_minutes.minutes).iso8601 },
      attendees: @activity.participants.map { |email| { email: email } }
    }
    if @activity.create_meet
      payload[:conferenceData] = { createRequest: { requestId: @activity.google_meet_request_id,
                                                   conferenceSolutionKey: { type: 'hangoutsMeet' } } }
    end
    payload
  end
end
