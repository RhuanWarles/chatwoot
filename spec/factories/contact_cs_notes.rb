# frozen_string_literal: true

FactoryBot.define do
  factory :contact_cs_note do
    account
    contact { association :contact, account: account }
    field_values { {} }
  end
end
