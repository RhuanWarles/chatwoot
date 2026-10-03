class AddCancellationDetailsToCrmActivities < ActiveRecord::Migration[7.2]
  def change
    add_column :crm_activities, :cancellation_reason, :text
    add_column :crm_activities, :cancelled_at, :datetime
    add_reference :crm_activities, :cancelled_by, index: true
  end
end
