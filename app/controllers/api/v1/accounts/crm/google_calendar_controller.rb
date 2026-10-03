class Api::V1::Accounts::Crm::GoogleCalendarController < Api::V1::Accounts::BaseController
  include CrmGoogleCalendarConcern
  COOKIE_NAME = :crm_google_calendar_oauth
  before_action :require_personal_user

  def show
    render json: { connected: connection.present?, configured: Crm::GoogleCalendarClient.configured?,
                   user_id: Current.user.id, email: connection&.google_email }
  end

  def create
    unless Crm::GoogleCalendarClient.configured?
      render json: { error: 'Google Calendar OAuth is not configured' }, status: :unprocessable_entity
      return
    end
    nonce = SecureRandom.hex(32)
    verifier = SecureRandom.urlsafe_base64(48)
    state = Rails.application.message_verifier('crm_google_calendar').generate(
      { account_id: Current.account.id, user_id: Current.user.id, nonce: nonce }, expires_in: 15.minutes, purpose: 'google_calendar'
    )
    cookies.encrypted[COOKIE_NAME] = {
      value: { nonce: nonce, verifier: verifier }.to_json, httponly: true, secure: request.ssl?, same_site: :lax, expires: 15.minutes.from_now
    }
    url = google_client.auth_code.authorize_url(
      redirect_uri: "#{ENV.fetch('FRONTEND_URL')}/crm/google_calendar/callback",
      scope: Crm::GoogleCalendarClient::SCOPE, access_type: 'offline', prompt: 'consent select_account', state: state,
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false), code_challenge_method: 'S256'
    )
    render json: { url: url }
  end

  def destroy
    revocation_failed = false
    if connection
      begin
        Crm::GoogleCalendarClient.new(connection).revoke
      rescue CustomExceptions::CrmCalendar
        revocation_failed = true
      ensure
        connection.destroy!
      end
    end
    render json: { connected: false, revocation_failed: revocation_failed }
  end

  private

  def require_personal_user
    raise Pundit::NotAuthorizedError unless Current.user.is_a?(User) && Current.account_user.present?
  end

  def connection
    @connection ||= Crm::GoogleCalendarConnection.find_by(account_id: Current.account.id, user_id: Current.user.id)
  end
end
