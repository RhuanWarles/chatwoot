class AddCrmDealSearchIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :crm_deals, :name, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently,
              name: 'index_crm_deals_on_name_search'
    add_index :companies, :name, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently,
              name: 'index_companies_on_name_search'
    add_index :contacts, "(additional_attributes->>'company_name') gin_trgm_ops", using: :gin,
              algorithm: :concurrently, name: 'index_contacts_on_legacy_company_search'
  end
end
