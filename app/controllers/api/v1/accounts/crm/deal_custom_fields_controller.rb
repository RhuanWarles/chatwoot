class Api::V1::Accounts::Crm::DealCustomFieldsController < Api::V1::Accounts::BaseController
  before_action :fetch_deal

  def show
    authorize @deal, :show?
    render json: field_payload
  end

  def update
    authorize @deal, :update?
    values = params.require(:values)
    unless values.is_a?(ActionController::Parameters)
      render json: { error: 'Valores devem ser um objeto' }, status: :unprocessable_entity
      return
    end
    fields = Current.account.crm_custom_fields.where(active: true).order(:position, :id).to_a
    unless (values.keys - fields.map(&:key)).empty?
      render json: { error: 'Campo indisponivel nesta conta' }, status: :unprocessable_entity
      return
    end
    @deal.with_lock(requires_new: true) do
      fields.each do |field|
        record = @deal.custom_field_values.find_or_initialize_by(custom_field_id: field.id)
        next unless values.key?(field.key) || field.required
        input = values.key?(field.key) ? values[field.key] : record.typed_value
        validate_input!(field, input)
        previous = record.typed_value
        record.account_id = Current.account.id
        record.typed_value = input
        record.save!
        next if previous == record.typed_value

        @deal.events.create!(
          account_id: Current.account.id, actor: Current.user, event_type: 'custom_field_changed',
          metadata: { field_name: field.name, field_key: field.key, field_type: field.field_type,
                      from: previous, to: record.typed_value }
        )
      end
    end
    render json: field_payload
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_deal
    @deal = policy_scope(Crm::Deal).find(params[:deal_id])
  end

  def field_payload
    records = @deal.custom_field_values.includes(:custom_field).index_by(&:custom_field_id)
    Current.account.crm_custom_fields.where(active: true).order(:position, :id).map do |field|
      field.as_json.merge('value' => records[field.id]&.typed_value)
    end
  end

  def validate_input!(field, input)
    return if input.nil?
    valid = case field.field_type
            when 'number', 'currency' then input.is_a?(Numeric) && input.finite?
            when 'boolean' then input == true || input == false
            when 'multiselect' then input.is_a?(Array) && input.all? { |item| item.is_a?(String) }
            else input.is_a?(String)
            end
    raise ArgumentError, "Valor invalido: #{field.name}" unless valid
  end
end
