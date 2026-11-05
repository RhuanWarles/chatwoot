class Crm::LostReasonFieldSyncJob < ApplicationJob
  queue_as :default

  def perform(account_id, renamed_from = nil, renamed_to = nil)
    account = Account.find_by(id: account_id)
    return unless account

    Crm::LostReasonField.rename_values(account, renamed_from, renamed_to)
    Crm::LostReasonField.sync!(account)
  end
end
