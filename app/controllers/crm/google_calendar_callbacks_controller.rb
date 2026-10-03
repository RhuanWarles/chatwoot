class Crm::GoogleCalendarCallbacksController < ApplicationController
  include CrmGoogleCalendarConcern

  def show
    state = Rails.application.message_verifier('crm_google_calendar').verified(params[:state], purpose: 'google_calendar')&.with_indifferent_access
    browser = JSON.parse(cookies.encrypted[:crm_google_calendar_oauth] || '{}')
    unless state && browser['nonce'].present? && ActiveSupport::SecurityUtils.secure_compare(state[:nonce], browser['nonce'])
      redirect_to '/app'
      return
    end
    cookies.delete(:crm_google_calendar_oauth)
    membership = AccountUser.find_by!(account_id: state[:account_id], user_id: state[:user_id])
    @account_id = membership.account_id
    return finish('failed') unless membership.account.active?
    return finish(params[:error] == 'access_denied' ? 'cancelled' : 'failed') if params[:error].present?

    token = google_client.auth_code.get_token(params.require(:code),
                                             redirect_uri: "#{ENV.fetch('FRONTEND_URL')}/crm/google_calendar/callback",
                                             code_verifier: browser.fetch('verifier'))
    unless token.params.fetch('scope', '').split.include?(Crm::GoogleCalendarClient::CALENDAR_SCOPE)
      return finish('failed')
    end
    connection = Crm::GoogleCalendarConnection.find_or_initialize_by(account_id: membership.account_id, user_id: membership.user_id)
    identity = token.get('https://openidconnect.googleapis.com/v1/userinfo').parsed
    return finish('failed') unless identity['sub'].present? && identity['email_verified'] == true

    refresh_token = token.refresh_token || (connection.provider_uid == identity['sub'] ? connection.refresh_token : nil)
    return finish('failed') if refresh_token.blank?

    connection.update!(provider_uid: identity.fetch('sub'), google_email: identity.fetch('email'), access_token: token.token,
                       refresh_token: refresh_token, expires_at: Time.at(token.expires_at))
    finish('connected')
  rescue OAuth2::Error, Faraday::Error, JSON::ParserError, ActiveRecord::RecordNotFound, ActionController::ParameterMissing
    @account_id ? finish('failed') : redirect_to('/app')
  end

  private

  def finish(result)
    redirect_to "/app/accounts/#{@account_id}/settings/integrations/google_calendar?result=#{result}"
  end
end
