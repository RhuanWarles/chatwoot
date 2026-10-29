class Api::V1::Accounts::Crm::LostReasonsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: [:index]
  before_action :fetch_lost_reason, only: [:update, :destroy]

  def index
    render json: Current.account.crm_lost_reasons.order(:position, :id)
  end

  def create
    position = Current.account.crm_lost_reasons.maximum(:position).to_i + 1
    lost_reason = Current.account.crm_lost_reasons.create!(lost_reason_params.reverse_merge(position: position))
    render json: lost_reason, status: :created
  end

  def update
    @lost_reason.update!(lost_reason_params)
    render json: @lost_reason
  end

  # A reason that deals already carry is kept (inactive) so the history and the automations do not lose it.
  def destroy
    if @lost_reason.deals.exists?
      @lost_reason.update!(active: false)
      render json: @lost_reason
    else
      @lost_reason.destroy!
      head :ok
    end
  end

  private

  def fetch_lost_reason
    @lost_reason = Current.account.crm_lost_reasons.find(params[:id])
  end

  def lost_reason_params
    params.require(:lost_reason).permit(:name, :position, :active)
  end
end
