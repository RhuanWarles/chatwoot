class Api::V1::Accounts::Crm::DealsController < Api::V1::Accounts::BaseController
  before_action :fetch_deal, only: [:show, :update, :destroy]
  before_action :authorize_deal, except: [:index]

  def index
    deals = filtered_deals
    deals = Crm::DealSearchService.new(scope: deals, account: Current.account, query: params[:q]).perform
    deals = deals.order(created_at: :desc) if params[:q].blank?
    deals = deals.to_a
    next_activities = next_activities_for(deals)
    labels = Crm::DealLabelsService.new(account: Current.account, user: Current.user, deals: deals).perform
    responders = Crm::DealRespondersService.new(account: Current.account, contact_ids: deals.map(&:contact_id)).perform

    render json: deals.map { |deal| deal_index_json(deal, next_activities[deal.id], labels[deal.id], responders[deal.contact_id]) }
  end

  def show
    render json: deal_json(@deal)
  end

  def create
    @deal = Current.account.crm_deals.new(deal_params)
    @deal.owner = Current.user if own_records_only?
    @deal.require_lost_reason = true
    @deal.save!
    render json: deal_json(@deal), status: :created
  end

  def update
    @deal.require_lost_reason = true
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

  # A plain agent's cards are always their own: they cannot hand one over or leave it without an owner.
  def deal_params
    permitted = [:name, :pipeline_id, :pipeline_stage_id, :contact_id, :segment_id, :value, :status, :description, :lost_reason_id, :lost_note]
    permitted << :owner_id unless own_records_only?
    params.require(:deal).permit(*permitted)
  end

  def own_records_only?
    Current.account_user&.own_records_only?
  end

  def next_activities_for(deals)
    return {} if deals.empty?

    Crm::Activity.where(
      account_id: Current.account.id,
      deal_id: deals.map(&:id),
      status: 'pending'
    ).includes(:owner).order(:due_at, :id).group_by(&:deal_id)
  end

  def filtered_deals
    deals = policy_scope(Crm::Deal).includes(
      :pipeline_stage, :segment, :lost_reason, custom_field_values: :custom_field, contact: :company, owner: { avatar_attachment: :blob }
    )
    deals = deals.where(pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
    deals = deals.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    deals
  end

  def deal_index_json(deal, activities, labels, responders)
    json = deal.as_json(
      include: {
        contact: { only: [:id, :name, :email, :phone_number, :additional_attributes], include: { company: { only: [:id, :name] } } },
        owner: { only: [:id, :name, :email] },
        segment: { only: [:id, :name, :color] },
        lost_reason: { only: [:id, :name] },
        pipeline_stage: { only: [:id, :name, :position, :color] },
        custom_field_values: {
          only: [:id, :custom_field_id, :value], methods: [:typed_value],
          include: { custom_field: { only: [:id, :name, :key, :field_type, :required, :active, :position, :options] } }
        }
      }
    )
    json['next_activity'] = next_activity_json(activities&.first)
    json['labels'] = labels
    json['answered_by'] = responders || Crm::DealRespondersService::NO_REPLIES
    json['owner']['thumbnail'] = deal.owner.avatar_url if deal.owner
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
        segment: { only: [:id, :name, :color] },
        lost_reason: { only: [:id, :name] },
        pipeline: { only: [:id, :name] },
        pipeline_stage: { only: [:id, :name, :position, :color] },
        custom_field_values: { only: [:id, :custom_field_id, :value], include: { custom_field: { only: [:id, :name, :key, :field_type, :required, :active, :position, :options] } } }
      }
    )
    json['contact']['thumbnail'] = deal.contact.avatar_url if deal.contact
    json
  end
end
