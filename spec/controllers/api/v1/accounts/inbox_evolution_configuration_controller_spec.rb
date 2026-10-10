require 'rails_helper'

RSpec.describe 'Inbox Evolution configuration API', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/evolution_configuration" }
  let(:service) { instance_double(Evolution::ChatwootConfiguration) }

  before do
    inbox.channel.update!(additional_attributes: { 'evolution_instance_name' => 'rwhub' })
    allow(Evolution::ChatwootConfiguration).to receive(:new).with(inbox).and_return(service)
  end

  it 'returns only non-secret Evolution settings for an administrator' do
    allow(service).to receive(:show).and_return(instance_name: 'rwhub', configured: true, sign_msg: true)

    get url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      'instance_name' => 'rwhub',
      'configured' => true,
      'sign_msg' => true
    )
  end

  it 'updates signMsg through the server-side Evolution client' do
    allow(service).to receive(:update_sign_msg).with(false).and_return(
      instance_name: 'rwhub', configured: true, sign_msg: false
    )

    patch url, params: { sign_msg: false }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(service).to have_received(:update_sign_msg).with(false)
  end

  it 'does not allow an agent to change the instance configuration' do
    create(:inbox_member, user: agent, inbox: inbox)
    allow(service).to receive(:update_sign_msg)

    patch url, params: { sign_msg: false }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(service).not_to have_received(:update_sign_msg)
  end

  it 'rejects a non-boolean signMsg value' do
    allow(service).to receive(:update_sign_msg)

    patch url, params: { sign_msg: 'false' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(service).not_to have_received(:update_sign_msg)
  end
end
