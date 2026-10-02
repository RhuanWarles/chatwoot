class Api::V1::Accounts::Crm::PipelinesController < Api::V1::Accounts::BaseController
  before_action :authorize_pipeline_management, except: [:index, :show]
  before_action :fetch_pipeline, only: [:show, :update, :destroy]

  def index
    @pipelines = policy_scope(Crm::Pipeline).includes(:stages).order(:name)
    render json: @pipelines.as_json(include: { stages: { only: [:id, :name, :position, :color] } })
  end

  def show
    render json: @pipeline.as_json(include: { stages: { only: [:id, :name, :position, :color] } })
  end

  def create
    @pipeline = Current.account.crm_pipelines.create!(pipeline_params)
    render json: @pipeline, status: :created
  end

  def update
    @pipeline.update!(pipeline_params)
    render json: @pipeline
  end

  def destroy
    if @pipeline.deals.exists?
      render json: { error: 'Move or delete deals before deleting this pipeline' }, status: :unprocessable_entity
      return
    end
    @pipeline.destroy!
    head :ok
  end

  private

  def fetch_pipeline
    @pipeline = policy_scope(Crm::Pipeline).find(params[:id])
  end

  def authorize_pipeline_management
    authorize(Crm::Pipeline)
  end

  def pipeline_params
    params.require(:pipeline).permit(:name, :description, :active)
  end
end
