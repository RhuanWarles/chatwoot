class Api::V1::Accounts::Crm::ActivitiesController < Api::V1::Accounts::BaseController
  rescue_from ActionController::BadRequest do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end

  PARAMETER_KEYS = %w[activity_type title description due_at owner_id status].freeze

  before_action :fetch_deal

  def index
    authorize(@deal, :show?)
    render json: @deal.activities.where(account_id: Current.account.id).includes(:owner).order(:due_at, :id)
                      .as_json(include: { owner: { only: [:id, :name] } })
  end

  def create
    authorize(@deal, :update?)
    @activity = @deal.activities.create!(activity_params.merge(account_id: Current.account.id, contact_id: @deal.contact&.id))
    render_activity(:created)
  end

  def update
    authorize(@deal, :update?)
    @activity = @deal.activities.where(account_id: Current.account.id).find(params[:id])
    @activity.update!(activity_params)
    render_activity(:ok)
  end

  private

  def fetch_deal
    @deal = policy_scope(Crm::Deal).find(params[:deal_id])
  end

  def activity_params
    activity = params.require(:activity)
    raise ActionController::BadRequest, 'Invalid activity parameters' unless activity.is_a?(ActionController::Parameters)

    permitted = activity.permit(*PARAMETER_KEYS)
    valid = activity.to_unsafe_h.slice(*PARAMETER_KEYS).all? do |key, value|
      case key
      when 'owner_id' then value.nil? || value.is_a?(Integer)
      when 'activity_type' then Crm::Activity::TYPES.include?(value)
      when 'status' then Crm::Activity::STATUSES.include?(value)
      when 'due_at' then value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})\z/)
      when 'title' then value.is_a?(String) && value.strip.present? && value.length <= 255
      when 'description' then value.nil? || value.is_a?(String)
      end
    end
    raise ActionController::BadRequest, 'Invalid activity parameters' unless valid

    permitted
  end

  def render_activity(status)
    render json: @activity.as_json(include: { owner: { only: [:id, :name] } }), status: status
  end
end
