class Api::V1::Accounts::Crm::PipelineStagesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline
  before_action :authorize_management
  before_action :fetch_stage, only: [:update, :destroy]

  def create
    @stage = @pipeline.stages.create!(stage_params.merge(account: Current.account, position: next_position))
    render json: @stage, status: :created
  end

  def update
    @stage.update!(stage_params)
    render json: @stage
  end

  def destroy
    if @stage.deals.exists?
      render json: { error: 'Move deals to another stage before deleting this stage' }, status: :unprocessable_entity
      return
    end
    @stage.destroy!
    head :ok
  end

  def reorder
    params.require(:stage_ids).each_with_index do |stage_id, index|
      @pipeline.stages.find(stage_id).update!(position: index)
    end
    render json: @pipeline.stages
  end

  private

  def fetch_pipeline
    @pipeline = policy_scope(Crm::Pipeline).find(params[:pipeline_id])
  end

  def fetch_stage
    @stage = @pipeline.stages.find(params[:id])
  end

  def authorize_management
    authorize(@pipeline, :update?)
  end

  def stage_params
    params.require(:pipeline_stage).permit(:name, :position, :color)
  end

  def next_position
    @pipeline.stages.maximum(:position).to_i + 1
  end
end
