class Workflows::Actions::ContactActions
  NAMES = %w[set_contact_field add_contact_label].freeze

  def initialize(context, _workflow)
    @context = context
    @account = context.account
  end

  def set_contact_field(params)
    fields = Array(params['fields'])
    keys = fields.map { |item| item['key'].to_s }
    known = @account.custom_attribute_definitions.with_attribute_model('contact_attribute').where(attribute_key: keys).pluck(:attribute_key)
    missing = keys - known
    raise Workflows::ActionRunner::MissingRecord, "Contact custom field #{missing.first} not found" if missing.any?

    values = fields.to_h { |item| [item['key'].to_s, item['value']] }
    contact.update!(custom_attributes: contact.custom_attributes.to_h.merge(values))
    { 'contact_id' => contact.id, 'fields' => keys }
  end

  def add_contact_label(params)
    contact.add_labels(Array(params['labels']))
    { 'contact_id' => contact.id }
  end

  private

  def contact
    @context.contact || raise(Workflows::ActionRunner::MissingRecord, 'No contact is available for this run')
  end
end
