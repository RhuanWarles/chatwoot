class Api::V1::Accounts::AiToolExecutionsController < Api::V1::Accounts::BaseController
  include SaasAiAccess
  before_action -> { require_ai_feature('text') }
  before_action :authorize_execution_access

  PER_PAGE = 25
  PERIODS = { 'today' => 1.day, '7d' => 7.days, '30d' => 30.days }.freeze

  def index
    executions = Current.account.saas_ai_tool_executions.includes(:ai_agent, :ai_tool, :conversation)
                             .order(created_at: :desc, id: :desc)
    executions = executions.where(conversation_id: @conversation.id) if @conversation
    executions = executions.where(ai_agent_id: params[:ai_agent_id]) if params[:ai_agent_id].present?
    executions = executions.where(ai_tool_id: params[:ai_tool_id]) if params[:ai_tool_id].present?
    executions = executions.where(status: params[:status]) if %w[completed failed].include?(params[:status])
    executions = filter_source(executions, params[:source]) if %w[conversation playground test unknown].include?(params[:source])
    executions = filter_period(executions)

    page = [params[:page].to_i, 1].max
    total = executions.count
    items = executions.limit(PER_PAGE).offset((page - 1) * PER_PAGE)
    render json: { executions: items.map { |execution| execution_data(execution) }, meta: { current_page: page, total_count: total, per_page: PER_PAGE } }
  end

  def show
    scope = Current.account.saas_ai_tool_executions.includes(:ai_agent, :ai_tool, :conversation)
    scope = scope.where(conversation_id: @conversation.id) if @conversation
    execution = scope.find(params[:id])
    render json: { execution: execution_data(execution, detailed: true) }
  end

  private

  def authorize_execution_access
    return check_admin_authorization? if params[:conversation_id].blank?

    @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize @conversation, :show?
  end

  def filter_source(scope, source)
    case source
    when 'conversation' then scope.where.not(conversation_id: nil).where(playground_session_id: nil)
    when 'playground' then scope.where(conversation_id: nil).where.not(playground_session_id: nil).where.not('playground_session_id LIKE ?', 'test:%')
    when 'test' then scope.where('playground_session_id LIKE ?', 'test:%')
    when 'unknown' then scope.where(conversation_id: nil, playground_session_id: nil)
    else scope
    end
  end

  def filter_period(scope)
    period = params[:period].to_s
    return scope.where(created_at: PERIODS.fetch(period).ago..) if PERIODS.key?(period)

    scope
  end

  def execution_data(execution, detailed: false)
    data = {
      id: execution.id, execution_id: execution.request_id, created_at: execution.created_at,
      agent: { id: execution.ai_agent_id, name: execution.ai_agent.name },
      tool: { id: execution.ai_tool_id, name: execution.ai_tool.name, slug: execution.ai_tool.slug },
      status: execution.status, response_status: execution.response_status, duration_ms: execution.duration_ms,
      source: execution.source, conversation_id: execution.conversation_id, error_code: execution.error_code
    }
    data[:arguments] = execution.safe_arguments if detailed
    data
  end
end
