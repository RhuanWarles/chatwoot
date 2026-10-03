class Api::V1::Accounts::Crm::ActivitiesController < Api::V1::Accounts::BaseController
  rescue_from ActionController::BadRequest do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end
  PARAMETER_KEYS = %w[activity_type title description due_at owner_id status duration_minutes create_meet cancellation_reason].freeze
  CALENDAR_FIELDS = %w[title description due_at duration_minutes participants create_meet].freeze
  before_action :fetch_deal

  def index
    authorize(@deal, :show?)
    render json: @deal.activities.where(account_id: Current.account.id)
                      .includes(:owner, :cancelled_by, :google_calendar_connection).order(:due_at, :id)
                      .map { |activity| activity_json(activity) }
  end

  def create
    authorize(@deal, :update?)
    @activity = @deal.activities.build(activity_params.merge(account_id: Current.account.id, contact_id: @deal.contact&.id))
    configure_calendar
    @activity.save!
    render json: activity_json(@activity), status: :created
  end

  def update
    authorize(@deal, :update?)
    @activity = scoped_activity
    check_calendar_owner
    @activity.with_lock do
      @activity.assign_attributes(activity_params)
      configure_calendar
      @activity.save!
    end
    render json: activity_json(@activity)
  end

  def retry_sync
    authorize(@deal, :update?)
    @activity = scoped_activity
    check_calendar_owner
    unless @activity.external_provider == 'google'
      raise ActionController::BadRequest, 'Activity is not linked to Google Calendar'
    end
    connection = own_connection
    unless connection && connection.provider_uid == @activity.google_account_uid
      raise ActionController::BadRequest, 'Reconnect the original Google Calendar account'
    end
    @activity.update!(google_calendar_connection: connection, sync_status: 'pending', sync_error: nil,
                      google_sync_revision: @activity.google_sync_revision + 1)
    render json: activity_json(@activity)
  end

  private

  def fetch_deal
    @deal = policy_scope(Crm::Deal).find(params[:deal_id])
  end

  def scoped_activity
    @deal.activities.where(account_id: Current.account.id).find(params[:id])
  end

  def own_connection
    Crm::GoogleCalendarConnection.find_by(account_id: Current.account.id, user_id: Current.user.id)
  end

  def check_calendar_owner
    if @activity.external_provider == 'google' && @activity.owner_id != Current.user.id
      raise Pundit::NotAuthorizedError
    end
  end

  def configure_calendar
    requested = params[:activity][:create_calendar] == true
    if requested && @activity.external_provider != 'google'
      connection = own_connection
      unless connection && @activity.activity_type == 'meeting' && [nil, Current.user.id].include?(@activity.owner_id)
        raise ActionController::BadRequest, 'Connect your calendar and select yourself as meeting owner'
      end
      @activity.assign_attributes(google_calendar_connection: connection, external_provider: 'google', owner_id: Current.user.id,
                                  google_account_uid: connection.provider_uid, google_event_id: SecureRandom.hex(16),
                                  google_calendar_id: connection.calendar_id, google_meet_request_id: SecureRandom.uuid)
    end
    if @activity.create_meet && @activity.external_provider != 'google'
      raise ActionController::BadRequest, 'Google Meet requires Google Calendar'
    end
    return unless @activity.external_provider == 'google'

    if @activity.owner_id != Current.user.id
      raise ActionController::BadRequest, 'The calendar owner cannot be changed'
    end
    if @activity.new_record? || CALENDAR_FIELDS.any? { |field| @activity.will_save_change_to_attribute?(field) } ||
       (@activity.will_save_change_to_status? && @activity.status != 'completed')
      @activity.assign_attributes(sync_status: 'pending', sync_error: nil, google_sync_revision: @activity.google_sync_revision + 1)
    end
  end

  def activity_params
    activity = params.require(:activity)
    raise ActionController::BadRequest, 'Invalid activity parameters' unless activity.is_a?(ActionController::Parameters)

    if activity.key?(:cancellation_reason) && !(activity[:cancellation_reason].is_a?(String) && activity[:cancellation_reason].strip.present?)
      raise ActionController::BadRequest, 'Informe o motivo do cancelamento.'
    end

    valid = activity.to_unsafe_h.slice(*PARAMETER_KEYS, 'participants', 'create_calendar').all? do |key, value|
      case key
      when 'owner_id' then value.nil? || value.is_a?(Integer)
      when 'activity_type' then Crm::Activity::TYPES.include?(value)
      when 'status' then Crm::Activity::STATUSES.include?(value)
      when 'due_at' then value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})\z/)
      when 'title' then value.is_a?(String) && value.strip.present? && value.length <= 255
      when 'cancellation_reason' then value.is_a?(String) && value.strip.present?
      when 'description' then value.nil? || value.is_a?(String)
      when 'duration_minutes' then value.is_a?(Integer) && Crm::Activity::DURATION_RANGE.cover?(value)
      when 'participants' then Crm::Activity.valid_participants?(value)
      when 'create_calendar', 'create_meet' then [true, false].include?(value)
      end
    end
    raise ActionController::BadRequest, 'Invalid activity parameters' unless valid

    if activity.key?(:cancellation_reason) &&
       !(activity[:status] == 'cancelled' && (@activity.nil? || @activity.status != 'cancelled'))
      raise ActionController::BadRequest, 'O motivo deve ser informado ao cancelar a atividade.'
    end
    if activity[:status] == 'cancelled' && (@activity.nil? || @activity.status != 'cancelled') &&
       !activity[:cancellation_reason].is_a?(String)
      raise ActionController::BadRequest, 'Informe o motivo do cancelamento.'
    end

    activity.permit(*PARAMETER_KEYS, participants: [])
  end

  def activity_json(activity)
    activity.as_json(except: [:google_account_uid, :google_meet_request_id],
                     include: { owner: { only: [:id, :name] }, cancelled_by: { only: [:id, :name] } })
            .merge(can_sync: activity.external_provider != 'google' || activity.owner_id == Current.user.id)
  end
end
