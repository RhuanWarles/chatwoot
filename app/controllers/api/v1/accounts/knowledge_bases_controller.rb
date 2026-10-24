class Api::V1::Accounts::KnowledgeBasesController < Api::V1::Accounts::BaseController
  include SaasAiAccess
  VALIDATORS = {
    'name' => ->(value) { value.is_a?(String) && value.strip.present? && value.length <= 100 },
    'description' => ->(value) { value.is_a?(String) && value.length <= 2000 },
    'active' => ->(value) { [true, false].include?(value) },
    'similarity_threshold' => ->(value) { value.is_a?(Numeric) && value.between?(0, 1) },
    'retrieval_top_k' => ->(value) { value.is_a?(Integer) && value.between?(1, 10) },
    'chunk_size' => ->(value) { value.is_a?(Integer) && value.between?(400, 10_000) },
    'chunk_overlap' => ->(value) { value.is_a?(Integer) && value.between?(0, 9_999) }
  }.freeze
  before_action -> { require_ai_feature('text') }
  before_action :check_admin_authorization?
  before_action :fetch_base, only: [:show, :update, :destroy, :search]
  rescue_from CustomExceptions::SaasError do |error|
    code, field = error.code.split(':', 2)
    body = { error: code }
    body[:field] = field if code == 'invalid_knowledge' && field.present?
    render json: body, status: :unprocessable_entity
  end
  rescue_from ActiveRecord::RecordInvalid do
    render json: { error: 'invalid_knowledge' }, status: :unprocessable_entity
  end

  def index
    render json: { bases: Current.account.saas_knowledge_bases.includes(:agents).order(:name).map(&:public_data) }
  end

  def show
    render json: @base.public_data
  end

  def create
    base = Current.account.saas_knowledge_bases.create!(base_params)
    render json: base.public_data, status: :created
  end

  def update
    @base.update!(base_params)
    render json: @base.public_data
  end

  def destroy
    @base.destroy!
    head :no_content
  end

  def search
    query = params[:query]
    raise CustomExceptions::SaasError, 'invalid_query' unless query.is_a?(String) && query.strip.present? && query.length <= 8000

    result = Saas::Knowledge::Retrieval.search_debug(account: Current.account,
                                                     bases: Current.account.saas_knowledge_bases.where(id: @base.id), query: query)
    render json: { sources: result[:sources], candidates: result[:candidates] }
  end

  private

  def fetch_base
    @base = Current.account.saas_knowledge_bases.find(params[:id])
  end

  def base_params
    input = params.require(:knowledge_base)
    invalid_knowledge! unless input.is_a?(ActionController::Parameters)

    normalized = normalize_base_input(input)
    invalid_key = normalized.keys.find { |key| !VALIDATORS.key?(key) || !VALIDATORS.fetch(key).call(normalized[key]) }
    invalid_knowledge!(invalid_key) if invalid_key

    ActionController::Parameters.new(normalized).permit(:name, :description, :active, :similarity_threshold,
                                                        :retrieval_top_k, :chunk_size, :chunk_overlap)
  end

  def invalid_knowledge!(field = nil)
    code = field.present? ? "invalid_knowledge:#{field}" : 'invalid_knowledge'
    raise CustomExceptions::SaasError, code
  end

  def normalize_base_input(input)
    normalized = input.each_pair.to_h
    normalized['description'] = '' if normalized['description'].nil?
    return normalized unless normalized.key?('similarity_threshold')

    normalized['similarity_threshold'] = normalize_similarity_threshold(normalized['similarity_threshold'])
    invalid_knowledge!('similarity_threshold') if normalized['similarity_threshold'] == :invalid
    normalized
  end

  def normalize_similarity_threshold(value)
    parsed = value.is_a?(String) ? Float(value) : value
    return parsed if parsed.nil? || (parsed.is_a?(Numeric) && parsed.finite?)

    :invalid
  rescue ArgumentError, TypeError
    :invalid
  end
end
