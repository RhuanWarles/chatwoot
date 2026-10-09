class Api::V1::Accounts::VoiceAgentsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_agent, only: [:show, :update, :destroy]
  rescue_from CustomExceptions::SaasError, ActiveRecord::RecordInvalid do
    render json: { error: 'invalid_settings' }, status: :unprocessable_entity
  end

  VALIDATORS = {
    'name' => ->(value) { value.is_a?(String) && value.strip.present? && value.length <= 100 },
    'description' => ->(value) { value.nil? || value.is_a?(String) },
    'provider' => ->(value) { Saas::VoiceAgent::PROVIDERS.include?(value) },
    'assistant_id' => ->(value) { value.nil? || (value.is_a?(String) && value.length <= 100) },
    'phone_number_id' => ->(value) { value.nil? || (value.is_a?(String) && value.length <= 100) },
    'active' => ->(value) { [true, false].include?(value) },
    'inbound_enabled' => ->(value) { [true, false].include?(value) },
    'outbound_enabled' => ->(value) { [true, false].include?(value) },
    'max_call_duration' => ->(value) { value.nil? || (value.is_a?(Integer) && Saas::VoiceAgent::DURATION_RANGE.cover?(value)) }
  }.freeze

  def index
    render json: { agents: Current.account.saas_voice_agents.order(:name, :id).map(&:public_data),
                   providers: Saas::VoiceAgent::PROVIDERS,
                   duration_range: [Saas::VoiceAgent::DURATION_RANGE.begin, Saas::VoiceAgent::DURATION_RANGE.end] }
  end

  def show
    render json: @agent.public_data
  end

  def create
    @agent = Current.account.saas_voice_agents.create!(agent_params)
    render json: @agent.public_data, status: :created
  end

  def update
    @agent.update!(agent_params)
    render json: @agent.public_data
  end

  def destroy
    @agent.destroy!
    head :no_content
  end

  private

  def fetch_agent
    @agent = Current.account.saas_voice_agents.find(params[:id])
  end

  def agent_params
    input = params.require(:voice_agent)
    unless input.is_a?(ActionController::Parameters) && (input.keys - VALIDATORS.keys).empty? &&
           input.each_pair.all? { |key, value| VALIDATORS.fetch(key).call(value) }
      raise CustomExceptions::SaasError, 'invalid_settings'
    end

    input.permit(*VALIDATORS.keys)
  end
end
