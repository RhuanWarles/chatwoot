class CreateWhatsappConnections < ActiveRecord::Migration[7.2]
  def change
    create_table :whatsapp_connections do |t|
      t.references :account, type: :integer, null: false, foreign_key: true
      t.references :inbox, type: :integer, index: { unique: true }, foreign_key: { on_delete: :nullify }
      t.string :display_name, null: false, limit: 100
      t.string :instance_name, null: false
      t.string :evolution_instance_id
      t.string :phone_number
      t.string :profile_name
      t.string :profile_picture_url
      t.string :status, null: false, default: 'disconnected'
      t.timestamps
    end
    add_index :whatsapp_connections, :instance_name, unique: true
  end
end
