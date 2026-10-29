class Api::V1::Accounts::AutomationWorkflowsController < Api::V1::Accounts::BaseController
  RUNS_LIMIT = 50

  before_action :check_authorization
  before_action :fetch_workflow, only: [:show, :update, :destroy, :run, :runs]

  def index
    workflows = Current.account.automation_workflows.order(:id).to_a
    last_runs = AutomationWorkflowRun.where(automation_workflow_id: workflows.map(&:id))
                                     .select('DISTINCT ON (automation_workflow_id) id, automation_workflow_id, status, started_at')
                                     .order(:automation_workflow_id, id: :desc).index_by(&:automation_workflow_id)
    render json: workflows.map { |workflow| workflow_json(workflow, last_runs[workflow.id]) }
  end

  def show
    render json: workflow_json(@workflow, @workflow.runs.order(:id).last)
  end

  def create
    workflow = Current.account.automation_workflows.create!(workflow_params)
    render json: workflow_json(workflow, nil), status: :created
  end

  def update
    @workflow.update!(workflow_params)
    render json: workflow_json(@workflow, @workflow.runs.order(:id).last)
  end

  def destroy
    @workflow.destroy!
    head :ok
  end

  def run
    run = Workflows::TriggerService.start(@workflow, 'manual', manual_run_context)
    return render json: { message: I18n.t('automation_workflows.errors.no_trigger') }, status: :unprocessable_entity unless run

    render json: { run_id: run.id }, status: :accepted
  end

  def runs
    render json: @workflow.runs.order(id: :desc).limit(RUNS_LIMIT).map(&:as_api_json)
  end

  private

  def fetch_workflow
    @workflow = Current.account.automation_workflows.find(params[:id])
  end

  def workflow_params
    params.require(:automation_workflow).permit(:name, :description, :active, graph: {})
  end

  # Only records of this account can seed a run. A conversation is given by the number people see (its display id).
  def manual_run_context
    {
      'deal_id' => Current.account.crm_deals.find_by(id: params[:deal_id])&.id,
      'contact_id' => Current.account.contacts.find_by(id: params[:contact_id])&.id,
      'conversation_id' => Current.account.conversations.find_by(display_id: params[:conversation_id])&.id
    }.compact
  end

  def workflow_json(workflow, last_run)
    workflow.as_json(only: [:id, :name, :description, :active, :graph, :trigger_events, :webhook_token, :created_at, :updated_at]).merge(
      'webhook_url' => "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/automation_workflows/#{workflow.webhook_token}",
      'last_run' => last_run&.as_json(only: [:id, :status, :started_at])
    )
  end
end
