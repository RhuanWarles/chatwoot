class Api::V1::Accounts::AiAgentPlaygroundController < Api::V1::Accounts::BaseController
  include SaasAiAccess

  before_action -> { require_ai_feature('text') }
  before_action :check_admin_authorization?
  before_action :fetch_agent
  rescue_from CustomExceptions::SaasError, with: :render_playground_error

  def show
    render json: playground.session(valid_session_id)
  end

  def create_message
    render json: playground.message(session_id: valid_session_id, request_id: valid_request_id, prompt: valid_prompt)
  end

  def destroy
    playground.clear(valid_session_id)
    head :no_content
  end

  private

  def fetch_agent
    @agent = Current.account.saas_ai_agents.find(params[:id])
  end

  def playground
    Saas::AiAgents::Playground.new(Current.account, Current.user, @agent)
  end

  def valid_session_id
    value = params[:session_id]
    raise CustomExceptions::SaasError, 'invalid_session_id' unless value.is_a?(String) && value.match?(Saas::AiAgents::Playground::SESSION_ID)

    value
  end

  def valid_request_id
    value = params[:request_id]
    raise CustomExceptions::SaasError, 'invalid_request_id' unless value.is_a?(String) && value.match?(Saas::AiAgents::Playground::SESSION_ID)

    value
  end

  def valid_prompt
    value = params[:message]
    raise CustomExceptions::SaasError, 'invalid_prompt' unless value.is_a?(String) && value.strip.present? && value.length <= 8000

    value.strip
  end

  def render_playground_error(error)
    status = error.code == 'text_ai_disabled' ? :forbidden : :unprocessable_entity
    render json: { error: error.code }, status: status
  end
end
