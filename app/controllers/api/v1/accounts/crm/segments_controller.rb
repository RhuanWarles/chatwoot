class Api::V1::Accounts::Crm::SegmentsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: [:index]
  before_action :fetch_segment, only: [:update, :destroy]

  def index
    render json: Current.account.crm_segments.order(:position, :id)
  end

  def create
    position = Current.account.crm_segments.maximum(:position).to_i + 1
    segment = Current.account.crm_segments.create!(segment_params.reverse_merge(position: position))
    render json: segment, status: :created
  end

  def update
    @segment.update!(segment_params)
    render json: @segment
  end

  # A segment that deals already carry is kept (inactive) so the history and the reports do not lose it.
  def destroy
    if @segment.deals.exists?
      @segment.update!(active: false)
      render json: @segment
    else
      @segment.destroy!
      head :ok
    end
  end

  private

  def fetch_segment
    @segment = Current.account.crm_segments.find(params[:id])
  end

  def segment_params
    params.require(:segment).permit(:name, :color, :position, :active)
  end
end
