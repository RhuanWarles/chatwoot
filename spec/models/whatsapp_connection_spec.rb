require 'rails_helper'

RSpec.describe WhatsappConnection do
  let(:account) { create(:account) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:connection) { account.whatsapp_connections.create!(display_name: 'Commercial', instance_name: 'account-instance', inbox: inbox) }

  it 'keeps a disconnected connection and unique technical name by default' do
    expect(connection.status).to eq('disconnected')
    duplicate = account.whatsapp_connections.new(display_name: 'Duplicate', instance_name: connection.instance_name)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:instance_name]).to be_present
  end

  it 'does not delete the connection when its inbox is deleted or call Evolution from model callbacks' do
    connection
    inbox.destroy!
    expect(connection.reload.inbox_id).to be_nil
    expect(connection.status).to eq('disconnected')
    expect(WebMock).not_to have_requested(:any, /evolution/)
  end

  it 'cleans local account associations without remote callbacks' do
    connection
    account.destroy!
    expect(described_class.exists?(connection.id)).to be(false)
    expect(WebMock).not_to have_requested(:any, /evolution/)
  end
end
