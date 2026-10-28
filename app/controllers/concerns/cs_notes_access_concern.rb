# Keeps the CS notes closed to everyone except the administrators and the team in charge (see CsNotes::Access).
module CsNotesAccessConcern
  extend ActiveSupport::Concern

  included do
    before_action :ensure_cs_access
  end

  private

  def cs_access
    @cs_access ||= CsNotes::Access.new(Current.account, Current.user)
  end

  def ensure_cs_access
    raise Pundit::NotAuthorizedError unless cs_access.allowed?
  end

  def cs_fields
    Current.account.custom_attribute_definitions.cs_attribute.order(:id)
  end

  def serialize_cs_field(field)
    field.slice(:id, :attribute_key, :attribute_display_name, :attribute_display_type, :attribute_description, :attribute_values,
                :attribute_model)
  end
end
