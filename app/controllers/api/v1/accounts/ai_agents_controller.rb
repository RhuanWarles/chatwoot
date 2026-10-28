class Api::V1::Accounts::AiAgentsController < Api::V1::Accounts::BaseController
  include SaasAiAccess
  before_action -> { require_ai_feature('text') }
  before_action :check_admin_authorization?
  before_action :fetch_agent, only: [:show, :update, :destroy, :memories, :clear_memory]
  rescue_from CustomExceptions::SaasError do
    render json: { error: 'invalid_settings' }, status: :unprocessable_entity
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    conflict = error.record.errors.details.fetch(:inboxes, []).any? { |detail| detail[:error] == :taken }
    payload = { error: conflict ? 'inbox_conflict' : 'invalid_settings' }
    if !conflict && error.record.errors.attribute_names.include?(:timezone)
      payload[:field] = 'timezone'
      payload[:message] = 'Use um identificador de fuso horário IANA válido.'
    end
    render json: payload, status: :unprocessable_entity
  end

  VALIDATORS = {
    'name' => ->(value) { value.is_a?(String) && value.strip.present? && value.length <= 100 },
    'description' => ->(value) { value.nil? || value.is_a?(String) },
    'system_prompt' => ->(value) { value.is_a?(String) && value.strip.present? },
    'provider' => ->(value) { Saas::AiAgent::PROVIDERS.include?(value) },
    'model' => ->(value) { value.is_a?(String) && value.strip.present? && value.length <= 100 },
    'timezone' => ->(value) { value.is_a?(String) && value.strip.present? },
    'temperature' => ->(value) { value.is_a?(Numeric) && value.finite? && Saas::AiAgent::TEMPERATURE_RANGE.cover?(value) },
    'context_messages_limit' => ->(value) { value.is_a?(Integer) && (1..100).cover?(value) },
    'response_delay_seconds' => ->(value) { value.is_a?(Integer) && (0..10).cover?(value) },
    'split_response_messages' => ->(value) { [true, false].include?(value) },
    'active' => ->(value) { [true, false].include?(value) },
    'handoff_enabled' => ->(value) { [true, false].include?(value) },
    'crm_stage_automation_enabled' => ->(value) { [true, false].include?(value) },
    'respond_to_groups' => ->(value) { [true, false].include?(value) },
    'group_response_blacklist' => ->(value) { Saas::AiAgents::GroupResponseBlacklist.valid?(value) },
    'customer_memory_enabled' => ->(value) { [true, false].include?(value) },

    'crm_pipeline_id' => ->(value) { value.nil? || (value.is_a?(Integer) && value.positive?) },
    'handoff_conditions' => ->(value) { value.nil? || (value.is_a?(String) && value.length <= Saas::AiAgent::HANDOFF_CONDITIONS_MAX_LENGTH) },
    'audio_enabled' => ->(value) { [true, false].include?(value) },
    'attachment_interpretation_enabled' => ->(value) { [true, false].include?(value) },

    'knowledge_base_ids' => lambda { |value|
      value.is_a?(Array) && value.all? { |id| id.is_a?(Integer) && id.positive? } && value.uniq == value
    },
    'tool_ids' => lambda { |value|
      value.is_a?(Array) && value.all? { |id| id.is_a?(Integer) && id.positive? } && value.uniq == value
    },
    'inbox_ids' => lambda { |value|
      value.is_a?(Array) && value.all? { |id| id.is_a?(Integer) && id.positive? } && value.uniq == value
    }
  }.freeze

  def index
    settings = Current.account.saas_ai_setting || Current.account.build_saas_ai_setting
    text_wallet = Saas::Wallet.for_account(Current.account, 'text_credits')
    render json: { agents: Current.account.saas_ai_agents.includes(:inboxes).order(:name, :id).map(&:public_data),
                   providers: Saas::AiAgent::PROVIDERS, temperature_range: [0, 1],
                   text: { mode: settings.text_mode, platform_ready: Saas::TextService.configured?,
                           platform_provider: ENV.fetch('SAAS_TEXT_PROVIDER', nil), platform_model: ENV.fetch('SAAS_TEXT_MODEL', nil),
                           credits_per_request: Saas::TextService.credits_per_request,
                           available_credits: text_wallet.available_units } }
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

  def memories
    memories = @agent.memories.where(account: Current.account).includes(:contact).order(updated_at: :desc)
    memories = memories.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    render json: memories.map { |memory| memory_data(memory) }
  end

  def clear_memory
    @agent.memories.where(account: Current.account, contact_id: params[:contact_id]).delete_all
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
      invalid_timezone = input.is_a?(ActionController::Parameters) && input.key?('timezone') &&
                         !VALIDATORS['timezone'].call(input['timezone'])
      if invalid_timezone
        @agent.errors.add(:timezone, :invalid)
        raise ActiveRecord::RecordInvalid, @agent
      end

      raise CustomExceptions::SaasError, 'invalid_settings'
    end

    validate_original_group_response_blacklist!(input)
    attributes = input.permit(*VALIDATORS.keys.excluding('inbox_ids', 'tool_ids', 'knowledge_base_ids', 'group_response_blacklist'),
                              inbox_ids: [], tool_ids: [], knowledge_base_ids: [], group_response_blacklist: []).to_h.symbolize_keys
    base_ids = attributes.delete(:knowledge_base_ids)
    selected_bases = Current.account.saas_knowledge_bases.where(id: base_ids).to_a unless base_ids.nil?
    raise CustomExceptions::SaasError, 'invalid_settings' if selected_bases && selected_bases.length != base_ids.length
    inbox_ids = attributes.delete(:inbox_ids)
    tool_ids = attributes.delete(:tool_ids)
    selected_inboxes = Current.account.inboxes.where(id: inbox_ids).to_a unless inbox_ids.nil?
    if selected_inboxes && selected_inboxes.length != inbox_ids.length
      @agent.errors.add(:inboxes, :invalid)
      raise ActiveRecord::RecordInvalid, @agent
    end
    selected_tools = Current.account.saas_ai_tools.where(id: tool_ids).to_a unless tool_ids.nil?
    if selected_tools && selected_tools.length != tool_ids.length
      @agent.errors.add(:tools, :invalid)
      raise ActiveRecord::RecordInvalid, @agent
    end
    @agent.configure!(attributes, selected_inboxes: selected_inboxes, selected_tools: selected_tools, selected_knowledge_bases: selected_bases)
  end

  def validate_original_group_response_blacklist!(input)
    return unless input.key?('group_response_blacklist') && request.content_mime_type == Mime[:json]

    # Rails removes null array entries before building params; validate the original JSON list as well.
    original = ActionDispatch::Request.parameter_parsers.fetch(:json).call(request.raw_post)
    numbers = original.dig('ai_agent', 'group_response_blacklist')
    return if VALIDATORS.fetch('group_response_blacklist').call(numbers)

    raise CustomExceptions::SaasError, 'invalid_settings'
  end

  def memory_data(memory)
    { id: memory.id, contact_id: memory.contact_id, contact_name: memory.contact.name, content: memory.content,
      updated_at: memory.updated_at,
      last_processed_message_id: memory.last_processed_message_id }
  end
end
