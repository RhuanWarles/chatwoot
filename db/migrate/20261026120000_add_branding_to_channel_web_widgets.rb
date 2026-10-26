class AddBrandingToChannelWebWidgets < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_web_widgets, :branding_text, :string
    add_column :channel_web_widgets, :branding_url, :string
  end
end
