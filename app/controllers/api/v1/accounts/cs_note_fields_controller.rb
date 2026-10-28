# The custom fields of the CS notes. They only exist here: they are not custom attributes of the contact.
class Api::V1::Accounts::CsNoteFieldsController < Api::V1::Accounts::BaseController
  include CsNotesAccessConcern

  before_action :field, only: [:update, :destroy]

  def index
    render json: cs_fields.map { |item| serialize_cs_field(item) }
  end

  def create
    created = Current.account.custom_attribute_definitions.create!(create_params.merge(attribute_model: 'cs_attribute'))
    render json: serialize_cs_field(created), status: :created
  end

  # The key and the type stay as they were created, so the values already written keep their meaning.
  def update
    field.update!(update_params)
    render json: serialize_cs_field(field)
  end

  def destroy
    key = field.attribute_key
    field.destroy!
    forget_values(key)
    head :no_content
  end

  private

  def field
    @field ||= cs_fields.find(params[:id])
  end

  def create_params
    attributes = params.require(:cs_note_field).permit(:attribute_display_name, :attribute_display_type, :attribute_description,
                                                       attribute_values: [])
    attributes.merge(attribute_key: unique_key(attributes[:attribute_display_name]))
  end

  def update_params
    params.require(:cs_note_field).permit(:attribute_display_name, :attribute_description, attribute_values: [])
  end

  # "Próximo contato" -> "proximo_contato"; a name taken already gets a number.
  def unique_key(name)
    base = name.to_s.parameterize(separator: '_')
    return base if base.blank? || !taken?(base)

    suffix = 2
    suffix += 1 while taken?("#{base}_#{suffix}")
    "#{base}_#{suffix}"
  end

  def taken?(key)
    cs_fields.exists?(attribute_key: key)
  end

  def forget_values(key)
    ContactCsNote.where(account_id: Current.account.id).find_each do |note|
      note.update!(field_values: note.field_values.except(key)) if note.field_values.key?(key)
    end
  end
end
