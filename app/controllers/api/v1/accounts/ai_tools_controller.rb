class Api::V1::Accounts::AiToolsController < Api::V1::Accounts::BaseController
  include SaasAiAccess
  before_action -> { require_ai_feature('text') }
  before_action :check_admin_authorization?
  before_action :fetch_tool, only: [:show, :update, :destroy, :test]

  def index
    render json: { tools: Current.account.saas_ai_tools.order(:name, :id).map(&:public_data) }
  end

  def show
    render json: @tool.public_data
  end

  def create
    @tool = Current.account.saas_ai_tools.build(tool_attributes)
    @tool.save!
    render json: @tool.public_data, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_tool(e)
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'tool_name_taken', message: 'A tool with this name already exists in this account.' }, status: :unprocessable_entity
  end

  def update
    @tool.assign_attributes(tool_attributes)
    @tool.save!
    render json: @tool.public_data
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_tool(e)
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'tool_name_taken', message: 'A tool with this name already exists in this account.' }, status: :unprocessable_entity
  end

  def destroy
    @tool.destroy!
    head :no_content
  end

  def test
    agent = Current.account.saas_ai_agents.find(params[:agent_id])
    result = Saas::AiTools::Executor.new(account: Current.account, agent: agent).call(@tool.slug, test_arguments)
    render json: result
  end

  private

  def fetch_tool
    @tool = Current.account.saas_ai_tools.find(params[:id])
  end

  def tool_attributes
    input = params.require(:ai_tool)
    permitted = input.permit(:name, :slug, :description, :tool_type, :active, :allow_in_playground,
                             configuration: [:method, :url, :timeout_seconds, :headers, :query_params, :body,
                                             { parameters: [:name, :type, :description, :required, :sensitive, enum_values: []] }],
                             secret_headers: {}).to_h
    extracted = {}
    if input.key?('configuration')
      configuration = permitted[:configuration].to_h.stringify_keys
      headers = configuration.fetch('headers', {}).to_h.stringify_keys
      secret_names = %w[authorization apikey x-api-key x-auth-token]
      extracted = headers.select { |name, _| secret_names.include?(name.downcase) }
      configuration['headers'] = headers.except(*extracted.keys)
      permitted[:configuration] = configuration
    else
      permitted.delete(:configuration)
    end
    supplied_secrets = input[:secret_headers].respond_to?(:to_h) ? input[:secret_headers].to_h : {}
    secrets = extracted.merge(supplied_secrets.stringify_keys)
    permitted[:secret_headers] = JSON.generate(secrets) if secrets.present?
    permitted.delete(:secret_headers) if secrets.blank?
    permitted
  end

  def render_invalid_tool(exception)
    message = if exception.record.errors.of_kind?(:slug, :taken)
                'A tool with this name already exists in this account.'
              else
                exception.record.errors.full_messages.to_sentence
              end
    render json: { error: 'invalid_tool', message: message }, status: :unprocessable_entity
  end

  def test_arguments
    value = params[:arguments]
    value.respond_to?(:to_h) ? value.to_h : {}
  end
end
