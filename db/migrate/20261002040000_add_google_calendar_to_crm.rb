class AddGoogleCalendarToCrm < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_google_calendar_connections do |t|
      t.references :account, null: false
      t.references :user, null: false
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.datetime :expires_at, null: false
      t.string :provider_uid, null: false
      t.string :google_email
      t.string :calendar_id, null: false, default: 'primary'
      t.timestamps
    end
    add_index :crm_google_calendar_connections, [:account_id, :user_id], unique: true, name: 'index_crm_google_connections_on_account_user'
    change_table :crm_activities, bulk: true do |t|
      t.integer :duration_minutes, null: false, default: 30
      t.jsonb :participants, null: false, default: []
      t.references :google_calendar_connection
      t.integer :google_sync_revision, null: false, default: 0
      t.string :google_account_uid
      t.string :external_provider
      t.string :google_event_id
      t.string :google_calendar_id
      t.string :google_meet_request_id
      t.string :meeting_url
      t.string :google_event_url
      t.boolean :create_meet, null: false, default: false
      t.string :sync_status
      t.string :sync_error
      t.datetime :synced_at
    end
    add_index :crm_activities, [:google_calendar_connection_id, :google_event_id], unique: true, name: 'index_crm_activities_on_google_event'
  end
end
