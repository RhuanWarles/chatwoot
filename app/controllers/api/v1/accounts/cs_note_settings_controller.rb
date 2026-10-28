# What the CS notes panel needs to know: whether the person can see it, the fields, and (for administrators) the team in charge.
class Api::V1::Accounts::CsNoteSettingsController < Api::V1::Accounts::BaseController
  include CsNotesAccessConcern

  # Everyone gets an answer, so the panel knows whether to show itself; only who is allowed gets the fields.
  skip_before_action :ensure_cs_access, only: [:show]
  before_action :check_admin_authorization?, only: [:update]

  def show
    render json: settings_payload
  end

  def update
    team_id = params[:team_id].presence
    team = team_id && Current.account.teams.find(team_id)
    Current.account.update!(cs_team_id: team&.id)

    render json: settings_payload
  end

  private

  def settings_payload
    allowed = cs_access.allowed?
    payload = { can_access: allowed, can_manage: cs_access.administrator? }
    return payload unless allowed

    payload[:fields] = cs_fields.map { |field| serialize_cs_field(field) }
    payload[:team_id] = cs_access.team_id if cs_access.administrator?
    payload
  end
end
