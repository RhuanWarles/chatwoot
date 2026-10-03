class Api::V1::Accounts::Crm::DealsController < Api::V1::Accounts::BaseController
  before_action :fetch_deal, only: [:show, :update, :destroy]
  before_action :authorize_deal, except: [:index]

  def index
    deals = policy_scope(Crm::Deal).includes(:contact, :owner, :pipeline_stage, custom_field_values: :custom_field)
    deals = deals.where(pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
    render json: deals.order(created_at: :desc).as_json(
      include: {
        contact: { only: [:id, :name, :email, :phone_number, :additional_attributes], include: { company: { only: [:id, :name] } } },
        owner: { only: [:id, :name, :email] },
        pipeline_stage: { only: [:id, :name, :position, :color] },
        custom_field_values: { only: [:id, :custom_field_id, :value], include: { custom_field: { only: [:id, :name, :key, :field_type, :required, :active, :position, :options] } } }
      }
    )
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
