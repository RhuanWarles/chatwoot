class Crm::GoogleCalendarClient
  include CrmGoogleCalendarConcern
  CALENDAR_SCOPE = 'https://www.googleapis.com/auth/calendar.events.owned'.freeze
  SCOPE = "openid email #{CALENDAR_SCOPE}".freeze
  API_URL = 'https://www.googleapis.com/calendar/v3/calendars'.freeze
  REFRESH_WINDOW = 2.minutes

  def initialize(connection)
    @connection = connection
  end

  def self.configured?
    GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil).present? &&
      GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil).present? && Chatwoot.encryption_configured?
  end

  def event(id)
    request(:get, id)
  end

  def insert(payload)
    request(:post, nil, payload)
  end

  def update(id, payload)
    request(:patch, id, payload)
  end

  def delete(id)
    request(:delete, id)
  end

  def revoke
    google_client.request(:post, 'https://oauth2.googleapis.com/revoke', body: { token: @connection.refresh_token })
  rescue OAuth2::Error, Faraday::Error
    raise CustomExceptions::CrmCalendar, 'google_revoke_failed', cause: nil
  end

  private

  def token
    @connection.with_lock do
      if @connection.expires_at <= Time.current + REFRESH_WINDOW
        refreshed = OAuth2::AccessToken.new(google_client, @connection.access_token,
                                           refresh_token: @connection.refresh_token).refresh!
        @connection.update!(access_token: refreshed.token, refresh_token: refreshed.refresh_token || @connection.refresh_token,
                            expires_at: Time.at(refreshed.expires_at))
      end
      OAuth2::AccessToken.new(google_client, @connection.access_token)
    end
  end

  def request(method, id, payload = nil)
    url = "#{API_URL}/#{ERB::Util.url_encode(@connection.calendar_id)}/events"
    url += "/#{ERB::Util.url_encode(id)}" if id
    options = {}
    options[:params] = { sendUpdates: 'all', conferenceDataVersion: 1 } if [:post, :patch].include?(method)
    options[:params] = { sendUpdates: 'all' } if method == :delete
    options[:body] = payload.to_json if payload
    options[:headers] = { 'Content-Type' => 'application/json' } if payload
    response = token.public_send(method, url, options)
    response.body.present? ? response.parsed : {}
  rescue OAuth2::Error => error
    return nil if method == :get && error.response.status == 404
    return {} if method == :delete && [404, 410].include?(error.response.status)
    return update(payload.fetch(:id), payload.except(:id)) if method == :post && error.response.status == 409

    raise CustomExceptions::CrmCalendar, 'google_api_failed', cause: nil
  rescue Faraday::Error
    raise CustomExceptions::CrmCalendar, 'google_api_failed', cause: nil
  end
end
