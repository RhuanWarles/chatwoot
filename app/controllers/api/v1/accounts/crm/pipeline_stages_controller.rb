class Api::V1::Accounts::Crm::PipelineStagesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline
  before_action :authorize_management
  before_action :fetch_stage, only: [:update, :destroy]

  before_action :validate_probability, only: [:create, :update]

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
    stage_ids = params.require(:stage_ids)
    unless stage_ids.is_a?(Array) && stage_ids.all? { |id| id.is_a?(Integer) } && stage_ids.sort == @pipeline.stages.ids.sort
      render json: { error: 'Stage IDs must include every stage exactly once' }, status: :unprocessable_entity
      return
    end

    @pipeline.transaction do
      stage_ids.each_with_index { |stage_id, index| @pipeline.stages.find(stage_id).update!(position: index) }
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
    params.require(:pipeline_stage).permit(:name, :position, :color, :probability)
  end

  def validate_probability
    probability = params.require(:pipeline_stage)[:probability]
    return if probability.nil? || (probability.is_a?(Integer) && probability.between?(0, 100))

    render json: { error: 'Probability must be an integer between 0 and 100' }, status: :unprocessable_entity
  end

  def next_position
    @pipeline.stages.maximum(:position).to_i + 1
  end
end
