class Api::V1::Accounts::Crm::CustomFieldsController < Api::V1::Accounts::BaseController
  before_action :fetch_field, only: [:show, :update, :destroy]

  def index
    render json: Current.account.crm_custom_fields.order(:position, :id)
  end

  def show
    render json: @field
  end

  def create
    key = field_params[:key].presence || field_params[:name].parameterize(separator: '_')
    field = Current.account.crm_custom_fields.create!(field_params.merge(key: key, position: field_params.fetch(:position) { next_position }))
    render json: field, status: :created
  end

  def reorder
    field_ids = params.require(:field_ids)
    fields = Current.account.crm_custom_fields
    unless field_ids.is_a?(Array) && field_ids.all?(Integer) && field_ids.sort == fields.ids.sort
      render json: { error: 'Field IDs must include every field exactly once' }, status: :unprocessable_entity
      return
    end

    fields.transaction { field_ids.each_with_index { |id, index| fields.find(id).update!(position: index) } }
    render json: fields.order(:position, :id)
  end

  # The field of the lost reason is kept by the system: only its name and place can change.
  def update
    attributes = field_params.except(:key)
    attributes = attributes.slice(:name, :position) if @field.system?
    @field.update!(attributes)
    render json: @field
  end

  def destroy
    return render json: { error: 'System fields cannot be removed' }, status: :unprocessable_entity if @field.system?

    if @field.deal_values.exists?
      @field.update!(active: false)
      render json: @field
    else
      @field.destroy!
      head :ok
    end
  end

  private

  def next_position
    Current.account.crm_custom_fields.maximum(:position).to_i + 1
  end

  def fetch_field
    @field = Current.account.crm_custom_fields.find(params[:id])
  end

  def field_params
    params.require(:custom_field).permit(:name, :key, :field_type, :required, :active, :position, options: [])
  end
end
