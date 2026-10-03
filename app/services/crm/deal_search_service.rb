class Crm::DealSearchService
  pattr_initialize [:scope!, :account!, :query!]

  def perform
    term = query.to_s.strip
    return scope if term.blank?

    search = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    digits = term.match?(/\A[\d\s()+.\-]+\z/) ? term.gsub(/\D/, '') : ''
    phone = digits.present? ? "%#{digits}%" : search
    companies = account.companies.where('name ILIKE ?', search).select(:id)
    contacts = account.contacts.where(
      "name ILIKE :search OR email ILIKE :search OR phone_number ILIKE :phone
       OR additional_attributes->>'company_name' ILIKE :search OR company_id IN (:companies)",
      search: search, phone: phone, companies: companies
    ).select(:id)
    matches = scope.where('crm_deals.name ILIKE ?', search).or(scope.where(contact_id: contacts))
    rank = ActiveRecord::Base.sanitize_sql_array([
      "CASE WHEN crm_deals.name ILIKE :search THEN 0 WHEN contacts.name ILIKE :search THEN 1
       WHEN contacts.phone_number ILIKE :phone OR contacts.email ILIKE :search THEN 2 ELSE 3 END",
      { search: search, phone: phone }
    ])
    matches.left_outer_joins(:contact).reorder(Arel.sql(rank), 'crm_deals.updated_at DESC', 'crm_deals.id DESC')
  end
end
