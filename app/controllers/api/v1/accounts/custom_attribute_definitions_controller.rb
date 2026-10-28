class Api::V1::Accounts::CustomAttributeDefinitionsController < Api::V1::Accounts::BaseController
  before_action :fetch_custom_attributes_definitions, except: [:create]
  before_action :fetch_custom_attribute_definition, only: [:show, :update, :destroy]
  before_action :check_authorization
  before_action :reject_cs_attribute_model, only: [:create, :update]
  DEFAULT_ATTRIBUTE_MODEL = 'conversation_attribute'.freeze

  def index; end

  def show; end

  def create
    @custom_attribute_definition = Current.account.custom_attribute_definitions.create!(
      permitted_payload
    )
  end

  def update
    @custom_attribute_definition.update!(permitted_payload)
  end

  def destroy
    @custom_attribute_definition.destroy!
    head :no_content
  end

  private

  def fetch_custom_attributes_definitions
    @custom_attribute_definitions = definitions.with_attribute_model(permitted_params[:attribute_model])
  end

  def fetch_custom_attribute_definition
    @custom_attribute_definition = definitions.find(permitted_params[:id])
  end

  # The fields of the CS notes are managed from the CS notes, never from here.
  def definitions
    Current.account.custom_attribute_definitions.where.not(attribute_model: :cs_attribute)
  end

  def reject_cs_attribute_model
    return unless params.dig(:custom_attribute_definition, :attribute_model).to_s == 'cs_attribute'

    render_could_not_create_error(I18n.t('errors.custom_attribute_definition.cs_attribute_model'))
  end

  def permitted_payload
    params.require(:custom_attribute_definition).permit(
      :attribute_display_name,
      :attribute_description,
      :attribute_display_type,
      :attribute_key,
      :attribute_model,
      :regex_pattern,
      :regex_cue,
      attribute_values: []
    )
  end

  def permitted_params
    params.permit(:id, :filter_type, :attribute_model)
  end
end
