class Api::V1::Accounts::KnowledgeBasesController < Api::V1::Accounts::BaseController
  include SaasAiAccess
  VALIDATORS = {
    'name' => ->(value) { value.is_a?(String) && value.strip.present? && value.length <= 100 },
    'description' => ->(value) { value.is_a?(String) && value.length <= 2000 },
    'active' => ->(value) { [true, false].include?(value) }
  }.freeze
  before_action -> { require_ai_feature('text') }
  before_action :check_admin_authorization?
  before_action :fetch_base, only: [:show, :update, :destroy, :search]
  rescue_from CustomExceptions::SaasError do |error|
    render json: { error: error.code }, status: :unprocessable_entity
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

    render json: { sources: Saas::Knowledge::Retrieval.search(account: Current.account,
                                                              bases: Current.account.saas_knowledge_bases.where(id: @base.id), query: query) }
  end

  private

  def fetch_base
    @base = Current.account.saas_knowledge_bases.find(params[:id])
  end

  def base_params
    input = params.require(:knowledge_base)
    valid = input.is_a?(ActionController::Parameters) && (input.keys - VALIDATORS.keys).empty? &&
            input.each_pair.all? { |key, value| VALIDATORS.fetch(key).call(value) }
    raise CustomExceptions::SaasError, 'invalid_knowledge' unless valid

    input.permit(:name, :description, :active)
  end
end
