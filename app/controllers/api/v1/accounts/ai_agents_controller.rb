class Api::V1::Accounts::AiAgentsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_agent, only: [:show, :update, :destroy]
  rescue_from CustomExceptions::SaasError do
    render json: { error: 'invalid_settings' }, status: :unprocessable_entity
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    conflict = error.record.errors.details.fetch(:inboxes, []).any? { |detail| detail[:error] == :taken }
    render json: { error: conflict ? 'inbox_conflict' : 'invalid_settings' }, status: :unprocessable_entity
  end

  VALIDATORS = {
    'name' => ->(value) { value.is_a?(String) && value.strip.present? && value.length <= 100 },
    'description' => ->(value) { value.nil? || value.is_a?(String) },
    'system_prompt' => ->(value) { value.is_a?(String) && value.strip.present? },
    'provider' => ->(value) { Saas::AiAgent::PROVIDERS.include?(value) },
    'model' => ->(value) { value.is_a?(String) && value.strip.present? && value.length <= 100 },
    'temperature' => ->(value) { value.is_a?(Numeric) && value.finite? && Saas::AiAgent::TEMPERATURE_RANGE.cover?(value) },
    'active' => ->(value) { [true, false].include?(value) },
    'handoff_enabled' => ->(value) { [true, false].include?(value) },
    'respond_to_groups' => ->(value) { [true, false].include?(value) },
    'inbox_ids' => lambda { |value|
      value.is_a?(Array) && value.all? { |id| id.is_a?(Integer) && id.positive? } && value.uniq == value
    }
  }.freeze

  def index
    render json: { agents: Current.account.saas_ai_agents.includes(:inboxes).order(:name, :id).map(&:public_data),
                   providers: Saas::AiAgent::PROVIDERS, temperature_range: [0, 1] }
  end

  def show
    render json: @agent.public_data
  end

  def create
    @agent = Current.account.saas_ai_agents.build
    configure_agent
    render json: @agent.public_data, status: :created
  end

  def update
    configure_agent
    render json: @agent.public_data
  end

  def destroy
    @agent.destroy!
    head :no_content
  end

  private

  def fetch_agent
    @agent = Current.account.saas_ai_agents.find(params[:id])
  end

  def configure_agent
    input = params.require(:ai_agent)
    unless input.is_a?(ActionController::Parameters) && (input.keys - VALIDATORS.keys).empty? &&
           input.each_pair.all? { |key, value| VALIDATORS.fetch(key).call(value) }
      raise CustomExceptions::SaasError, 'invalid_settings'
    end

    attributes = input.permit(*VALIDATORS.keys.excluding('inbox_ids'), inbox_ids: []).to_h.symbolize_keys
    inbox_ids = attributes.delete(:inbox_ids)
    selected_inboxes = Current.account.inboxes.where(id: inbox_ids).to_a unless inbox_ids.nil?
    if selected_inboxes && selected_inboxes.length != inbox_ids.length
      @agent.errors.add(:inboxes, :invalid)
      raise ActiveRecord::RecordInvalid, @agent
    end
    @agent.configure!(attributes, selected_inboxes: selected_inboxes)
  end
end
