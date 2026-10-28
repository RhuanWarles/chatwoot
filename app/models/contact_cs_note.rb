# == Schema Information
#
# Table name: contact_cs_notes
#
#  id           :bigint           not null, primary key
#  field_values :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  contact_id   :bigint           not null
#
# Indexes
#
#  index_contact_cs_notes_on_account_id  (account_id)
#  index_contact_cs_notes_on_contact_id  (contact_id) UNIQUE
#
class ContactCsNote < ApplicationRecord
  belongs_to :account
  belongs_to :contact

  VALUE_LIMIT = 5_000

  validates :contact_id, uniqueness: true

  # Applies the changes sent for some of the fields. Only the fields that still exist are kept; an empty value clears the field.
  def merge_field_values(changes, definitions)
    by_key = definitions.index_by(&:attribute_key)
    merged = field_values.slice(*by_key.keys)

    changes.each do |key, value|
      definition = by_key[key.to_s]
      next if definition.blank?

      if empty_value?(value)
        merged.delete(key.to_s)
      elsif acceptable?(definition, value)
        merged[key.to_s] = value
      end
    end

    self.field_values = merged
  end

  private

  def empty_value?(value)
    value.nil? || value == ''
  end

  # Only plain values are kept: text, numbers and yes/no.
  def scalar?(value)
    return value.length <= VALUE_LIMIT if value.is_a?(String)

    value.is_a?(Numeric) || [true, false].include?(value)
  end

  def acceptable?(definition, value)
    return false unless scalar?(value)
    return definition.attribute_values.include?(value) if definition.list?
    return [true, false].include?(value) if definition.checkbox?

    true
  end
end
