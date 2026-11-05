class SyncLostReasonFieldForExistingAccounts < ActiveRecord::Migration[7.1]
  # Accounts that already have lost reasons get the "Motivo da perda" field (and its values) without anyone touching a reason.
  # The work runs in a job; a failure to enqueue must not stop the deploy, because the first lost deal asks for the sync again.
  def up
    select_values('SELECT DISTINCT account_id FROM crm_lost_reasons').each do |account_id|
      Crm::LostReasonFieldSyncJob.perform_later(account_id.to_i)
    end
  rescue StandardError => e
    say "Could not enqueue the lost reason field sync: #{e.message}"
  end

  def down; end
end
