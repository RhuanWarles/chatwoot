class Api::V1::Accounts::Crm::DealsController < Api::V1::Accounts::BaseController
  before_action :fetch_deal, only: [:show, :update, :destroy]
  before_action :authorize_deal, except: [:index]

  def index
    deals = policy_scope(Crm::Deal).includes(:contact, :owner, :pipeline_stage, custom_field_values: :custom_field)
    deals = deals.where(pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
    deals = Crm::DealSearchService.new(scope: deals, account: Current.account, query: params[:q]).perform
    deals = deals.order(created_at: :desc) if params[:q].blank?
    deals = deals.to_a
    next_activities = next_activities_for(deals)

    render json: deals.map { |deal| deal_index_json(deal, next_activities[deal.id]) }
  end

  def show
    render json: deal_json(@deal)
  end

  def create
    @deal = Current.account.crm_deals.create!(deal_params)
    render json: deal_json(@deal), status: :created
  end

  def update
    @deal.update!(deal_params)
    render json: deal_json(@deal)
  end

  def destroy
    @deal.destroy!
    head :ok
  end

  private

  def fetch_deal
    @deal = policy_scope(Crm::Deal).find(params[:id])
  end

  def authorize_deal
    authorize(@deal || Crm::Deal)
  end

  def deal_params
    params.require(:deal).permit(
      :name, :pipeline_id, :pipeline_stage_id, :contact_id, :owner_id, :value, :status, :description
    )
  end

  def next_activities_for(deals)
    return {} if deals.empty?

    Crm::Activity.where(
      account_id: Current.account.id,
      deal_id: deals.map(&:id),
      status: 'pending'
    ).includes(:owner).order(:due_at, :id).group_by(&:deal_id)
  end

  def deal_index_json(deal, activities)
    json = deal.as_json(
      include: {
        contact: { only: [:id, :name, :email, :phone_number, :additional_attributes], include: { company: { only: [:id, :name] } } },
        owner: { only: [:id, :name, :email] },
        pipeline_stage: { only: [:id, :name, :position, :color] },
        custom_field_values: { only: [:id, :custom_field_id, :value], include: { custom_field: { only: [:id, :name, :key, :field_type, :required, :active, :position, :options] } } }
      }
    )
    json['next_activity'] = next_activity_json(activities&.first)
    json
  end

  def next_activity_json(activity)
    return nil unless activity

    activity.as_json(
      only: [:id, :activity_type, :title, :due_at, :duration_minutes, :status],
      include: { owner: { only: [:id, :name] } }
    )
  end

  def deal_json(deal)
    json = deal.as_json(
      include: {
        contact: { only: [:id, :name, :email, :phone_number, :additional_attributes], include: { company: { only: [:id, :name] } } },
        owner: { only: [:id, :name, :email] },
        pipeline: { only: [:id, :name] },
        pipeline_stage: { only: [:id, :name, :position, :color] },
        custom_field_values: { only: [:id, :custom_field_id, :value], include: { custom_field: { only: [:id, :name, :key, :field_type, :required, :active, :position, :options] } } }
      }
    )
    json['contact']['thumbnail'] = deal.contact.avatar_url if deal.contact
    json
  end
end
