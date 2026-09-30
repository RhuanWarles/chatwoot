class CreateSaasAiUsage < ActiveRecord::Migration[7.2]
  def change
    create_ai_settings
    create_wallets
    create_usage_records
    create_voice_calls
    create_text_generations
  end

  private

  def create_ai_settings
    create_table :saas_ai_settings do |t|
      t.references :account, null: false, index: { unique: true }
      t.string :text_mode, null: false, default: 'platform'
      t.string :text_provider, null: false, default: 'openai'
      t.string :text_model
      t.text :text_api_key
      t.boolean :inbound_enabled, null: false, default: false
      t.boolean :outbound_enabled, null: false, default: false
      t.integer :max_call_seconds, null: false, default: 600
      t.string :vapi_assistant_id
      t.string :vapi_phone_number_id
      t.timestamps
    end
    add_index :saas_ai_settings, :vapi_phone_number_id, unique: true
  end

  def create_wallets
    create_table :saas_wallets do |t|
      t.references :account, null: false
      t.string :resource, null: false
      t.bigint :balance_units, null: false, default: 0
      t.timestamps
    end
    add_index :saas_wallets, [:account_id, :resource], unique: true
  end

  def create_usage_records
    create_table :saas_usage_records do |t|
      t.references :wallet, null: false, index: false
      t.string :reference, null: false
      t.string :kind, null: false
      t.string :status, null: false
      t.bigint :reserved_units, null: false, default: 0
      t.bigint :units, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :saas_usage_records, [:wallet_id, :reference], unique: true
    add_index :saas_usage_records, [:wallet_id, :status]
  end

  def create_voice_calls
    create_table :saas_voice_calls do |t|
      t.references :account, null: false
      t.references :contact
      t.references :usage_record, null: false, index: { unique: true }
      t.string :request_id, null: false
      t.string :provider_call_id
      t.string :direction, null: false
      t.string :status, null: false, default: 'pending'
      t.string :customer_number, null: false
      t.string :assistant_id, null: false
      t.string :phone_number_id, null: false
      t.integer :max_duration_seconds, null: false
      t.timestamps
    end
    add_index :saas_voice_calls, [:account_id, :request_id], unique: true
    add_index :saas_voice_calls, :provider_call_id, unique: true
    add_voice_result_columns
  end

  def add_voice_result_columns
    add_column :saas_voice_calls, :duration_seconds, :integer, null: false, default: 0
    add_column :saas_voice_calls, :ended_reason, :string
    add_column :saas_voice_calls, :summary, :text
    add_column :saas_voice_calls, :transcript, :text
  end

  def create_text_generations
    create_table :saas_text_generations do |t|
      t.references :account, null: false
      t.references :usage_record
      t.string :request_id, null: false
      t.string :mode, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.string :status, null: false, default: 'pending'
      t.text :prompt, null: false
      t.text :response
      t.string :error_code
      t.integer :input_tokens
      t.integer :output_tokens
      t.timestamps
    end
    add_index :saas_text_generations, [:account_id, :request_id], unique: true
  end
end
