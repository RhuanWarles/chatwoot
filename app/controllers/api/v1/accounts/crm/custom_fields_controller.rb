class Api::V1::Accounts::Crm::CustomFieldsController < Api::V1::Accounts::BaseController
  before_action :fetch_field, only: [:show, :update, :destroy]

  def index
    render json: Current.account.crm_custom_fields.order(:position, :id)
  end

  def show
    render json: @field
  end

  def create
    field = Current.account.crm_custom_fields.create!(field_params.merge(key: field_params[:key].presence || field_params[:name].parameterize(separator: '_')))
    render json: field, status: :created
  end

  def update
    @field.update!(field_params.except(:key))
    render json: @field
  end

  def destroy
    if @field.deal_values.exists?
      @field.update!(active: false)
      render json: @field
    else
      @field.destroy!
      head :ok
    end
  end

  private

  def fetch_field
    @field = Current.account.crm_custom_fields.find(params[:id])
  end

  def field_params
    params.require(:custom_field).permit(:name, :key, :field_type, :required, :active, :position, options: [])
  end
end
