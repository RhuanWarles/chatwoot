# The values of the CS notes of a contact. They are not part of the contact, so they never reach agents outside the CS team.
class Api::V1::Accounts::Contacts::CsNotesController < Api::V1::Accounts::Contacts::BaseController
  include CsNotesAccessConcern

  def show
    render json: payload(cs_note)
  end

  # Only the fields sent are changed; an empty value clears the field.
  def update
    cs_note.merge_field_values(params.fetch(:field_values, {}).permit!.to_h, cs_fields)
    cs_note.save!

    render json: payload(cs_note)
  end

  private

  def cs_note
    @cs_note ||= ContactCsNote.find_or_initialize_by(account_id: Current.account.id, contact_id: @contact.id)
  end

  def payload(note)
    { field_values: note.field_values.slice(*cs_fields.pluck(:attribute_key)), updated_at: note.updated_at }
  end
end
