require 'rails_helper'

RSpec.describe 'WhatsApp connections API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:connection) { account.whatsapp_connections.create!(display_name: 'Commercial', instance_name: "account-#{account.id}-a8f3c920") }
  let(:collection_url) { "/api/v1/accounts/#{account.id}/whatsapp_connections" }
  let(:member_url) { "#{collection_url}/#{connection.id}" }
  let(:provider_url) { 'https://evolution.example.test' }
  let(:instance_name) { connection.instance_name }
  let(:qr_code) { 'data:image/png;base64,aGVsbG8=' }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }
  let(:provider_profile) do
    { id: 'remote-instance-id', name: instance_name, ownerJid: '5562999999999@s.whatsapp.net', profileName: 'Rhuan',
      profilePicUrl: 'https://example.test/avatar.png', token: 'never-return-instance-token', Chatwoot: { token: 'never-return-chatwoot-token' } }
  end

  around do |example|
    with_modified_env EVOLUTION_API_URL: provider_url, EVOLUTION_API_KEY: 'backend-only-evolution-key', FRONTEND_URL: 'https://chat.example.test' do
      example.run
    end
  end

  it 'hides the API without a provider URL and never calls the provider' do
    with_modified_env EVOLUTION_API_URL: nil do
      get collection_url, headers: admin.create_new_auth_token, as: :json
    end
    expect(response).to have_http_status(:not_found)
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'hides the API without a provider key' do
    with_modified_env EVOLUTION_API_KEY: nil do
      get collection_url, headers: admin.create_new_auth_token, as: :json
    end
    expect(response).to have_http_status(:not_found)
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'lists only this account connections and preserves unmatched legacy inbox configuration' do
    connection
    other_account = create(:account)
    other_account.whatsapp_connections.create!(display_name: 'Other account', instance_name: 'other-account-instance')
    inbox.channel.update!(additional_attributes: { 'evolution_instance_name' => 'legacy-rhuan' })

    get collection_url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['connections'].pluck('id')).to eq([connection.id])
    expect(response.parsed_body['inboxes']).to include('id' => inbox.id, 'name' => inbox.name, 'legacy_instance_name' => 'legacy-rhuan')
    expect(inbox.channel.reload.additional_attributes['evolution_instance_name']).to eq('legacy-rhuan')
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'does not allow agents to manage connections' do
    get collection_url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'creates a local connection before creating the provider instance and returns only a sanitized QR response' do
    stub_request(:post, "#{provider_url}/instance/create").with do |request|
      name = JSON.parse(request.body).fetch('instanceName')
      expect(account.whatsapp_connections.find_by!(instance_name: name)).to be_present
      expect(name).to match(/\Aaccount-#{account.id}-[0-9a-f]{16}\z/)
      true
    end.to_return(status: 201, headers: json_headers, body: { instance: { instanceId: 'new-instance' }, hash: 'never-return-hash' }.to_json)
    stub_request(:get, %r{#{provider_url}/instance/connectionState/account-#{account.id}-[0-9a-f]+})
      .to_return(headers: json_headers, body: { instance: { state: 'close' } }.to_json)
    stub_request(:get, %r{#{provider_url}/instance/connect/account-#{account.id}-[0-9a-f]+})
      .to_return(headers: json_headers, body: { base64: qr_code, token: 'never-return-qr-token' }.to_json)

    post collection_url, params: { display_name: ' Sales ', instance_name: 'malicious-instance' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('display_name' => 'Sales', 'status' => 'connecting', 'qr_code' => qr_code)
    expect(response.body).not_to include('backend-only-evolution-key', 'never-return', 'malicious-instance')
    expect(account.whatsapp_connections.last.evolution_instance_id).to eq('new-instance')
  end

  it 'rejects invalid names and non-integer inbox identifiers before creating an instance' do
    ['', 'a' * 101, 123].each do |name|
      post collection_url, params: { display_name: name }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
    post collection_url, params: { display_name: 'Commercial', inbox_id: inbox.id.to_s }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.whatsapp_connections.count).to eq(0)
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'creates and links an inbox through the complete provisioning flow' do
    technical_name = /account-#{account.id}-[0-9a-f]{16}/
    stub_request(:post, "#{provider_url}/instance/create")
      .to_return(headers: json_headers, body: { instance: { instanceId: 'new-bound-instance' } }.to_json)
    stub_request(:get, %r{#{provider_url}/chatwoot/find/#{technical_name}})
      .to_return(headers: json_headers, body: { enabled: false }.to_json)
    stub_request(:post, %r{#{provider_url}/chatwoot/set/#{technical_name}})
      .to_return(headers: json_headers, body: { enabled: true }.to_json)
    stub_request(:get, %r{#{provider_url}/instance/connectionState/#{technical_name}})
      .to_return(headers: json_headers, body: { instance: { state: 'close' } }.to_json)
    stub_request(:get, %r{#{provider_url}/instance/connect/#{technical_name}})
      .to_return(headers: json_headers, body: { base64: qr_code }.to_json)

    post collection_url, params: { display_name: 'Bound connection', inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    created = account.whatsapp_connections.find(response.parsed_body.fetch('id'))
    expect(created.inbox_id).to eq(inbox.id)
    expect(inbox.channel.reload.additional_attributes['evolution_instance_name']).to eq(created.instance_name)
    expect(response.parsed_body['qr_code']).to eq(qr_code)
  end

  it 'keeps the local record visible instead of automatically retrying uncertain instance creation' do
    create_instance = stub_request(:post, "#{provider_url}/instance/create").to_timeout
    post collection_url, params: { display_name: 'Uncertain connection' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:bad_gateway)
    expect(response.parsed_body.dig('connection', 'id')).to eq(account.whatsapp_connections.last.id)
    expect(account.whatsapp_connections.last.status).to eq('error')
    expect(create_instance).to have_been_requested.once
  end

  it 'rejects a non-API inbox before any provider creation' do
    web_inbox = create(:channel_widget, account: account).inbox
    post collection_url, params: { display_name: 'Commercial', inbox_id: web_inbox.id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'rejects duplicate inbox names because the current adapter correlates by name' do
    create(:channel_api, account: account).inbox.update!(name: inbox.name)
    post collection_url, params: { display_name: 'Commercial', inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error_code']).to eq('ambiguous_inbox')
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'prevents another account from accessing every member operation' do
    outsider = create(:user, account: create(:account), role: :administrator)
    %w[get patch delete].each do |method|
      public_send(method, member_url, params: { display_name: 'Hijacked' }, headers: outsider.create_new_auth_token, as: :json)
      expect(response).to have_http_status(:unauthorized)
    end
    %w[connect disconnect].each do |operation|
      post "#{member_url}/#{operation}", headers: outsider.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'cannot resolve a foreign connection even when the user administers both accounts' do
    foreign_account = create(:account)
    create(:account_user, account: foreign_account, user: admin, role: :administrator)
    foreign_connection = foreign_account.whatsapp_connections.create!(display_name: 'Foreign', instance_name: 'foreign-instance')
    get "#{collection_url}/#{foreign_connection.id}", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'rejects binding to a foreign inbox without calling the provider' do
    foreign_inbox = create(:channel_api).inbox
    patch member_url, params: { inbox_id: foreign_inbox.id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'configures the existing adapter and inbox webhook without exposing credentials' do
    inbox.channel.update!(additional_attributes: { 'another_setting' => 'preserved' })
    stub_request(:get, "#{provider_url}/chatwoot/find/#{instance_name}")
      .to_return(headers: json_headers, body: { enabled: false }.to_json)
    configure = stub_request(:post, "#{provider_url}/chatwoot/set/#{instance_name}").with do |request|
      body = JSON.parse(request.body)
      expect(body).to include('enabled' => true, 'autoCreate' => false, 'accountId' => account.id.to_s,
                              'nameInbox' => inbox.name, 'token' => admin.access_token.token, 'url' => 'https://chat.example.test')
      true
    end.to_return(headers: json_headers, body: { token: 'never-return-token', enabled: true }.to_json)

    patch member_url, params: { inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(configure).to have_been_requested.once
    expect(connection.reload.inbox_id).to eq(inbox.id)
    expect(inbox.channel.reload.additional_attributes).to include('evolution_instance_name' => instance_name, 'another_setting' => 'preserved')
    expect(inbox.channel.webhook_url).to eq("#{provider_url}/chatwoot/webhook/#{instance_name}")
    expect(response.body).not_to include('backend-only-evolution-key', admin.access_token.token, 'never-return-token')
  end

  it 'does not allow two managed connections to claim the same inbox' do
    connection.update!(inbox: inbox)
    other_connection = account.whatsapp_connections.create!(display_name: 'Second', instance_name: 'second-instance')
    patch "#{collection_url}/#{other_connection.id}", params: { inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error_code']).to eq('inbox_in_use')
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'moves a connection to another inbox, preserving other old channel settings and adapter options' do
    connection.update!(inbox: inbox)
    inbox.channel.update!(webhook_url: "#{provider_url}/chatwoot/webhook/#{instance_name}",
                          additional_attributes: { 'evolution_instance_name' => instance_name, 'other' => true })
    new_inbox = create(:channel_api, account: account).inbox
    new_inbox.update!(name: 'Commercial destination')
    stub_request(:get, "#{provider_url}/chatwoot/find/#{instance_name}")
      .to_return(headers: json_headers, body: { enabled: true, nameInbox: inbox.name, signMsg: true, importContacts: true }.to_json)
    configure = stub_request(:post, "#{provider_url}/chatwoot/set/#{instance_name}").with do |request|
      JSON.parse(request.body).slice('nameInbox', 'signMsg', 'importContacts') ==
        { 'nameInbox' => new_inbox.name, 'signMsg' => true, 'importContacts' => true }
    end.to_return(headers: json_headers, body: { enabled: true }.to_json)

    patch member_url, params: { inbox_id: new_inbox.id }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(configure).to have_been_requested.once
    expect(connection.reload.inbox_id).to eq(new_inbox.id)
    expect(inbox.channel.reload.additional_attributes).to eq('other' => true)
    expect(inbox.channel.webhook_url).to be_nil
    expect(new_inbox.channel.reload.additional_attributes['evolution_instance_name']).to eq(instance_name)
  end

  it 'explicitly unlinks without deleting the provider instance, inbox or conversations' do
    connection.update!(inbox: inbox)
    inbox.channel.update!(additional_attributes: { 'evolution_instance_name' => instance_name })
    stub_request(:get, "#{provider_url}/chatwoot/find/#{instance_name}")
      .to_return(headers: json_headers, body: { enabled: true, token: 'provider-token' }.to_json)
    stub_request(:post, "#{provider_url}/chatwoot/set/#{instance_name}").with do |request|
      JSON.parse(request.body)['enabled'] == false
    end.to_return(headers: json_headers, body: { enabled: false }.to_json)

    patch member_url, params: { inbox_id: nil }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(connection.reload.inbox_id).to be_nil
    expect(Inbox.exists?(inbox.id)).to be(true)
    expect(inbox.channel.reload.additional_attributes).not_to have_key('evolution_instance_name')
    expect(WebMock).not_to have_requested(:delete, "#{provider_url}/instance/delete/#{instance_name}")
  end

  it 'synchronizes connection status, number and profile without returning provider secrets' do
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { state: 'open' } }.to_json)
    stub_request(:get, "#{provider_url}/instance/fetchInstances").with(query: { instanceName: instance_name })
                                                                 .to_return(headers: json_headers, body: [provider_profile].to_json)

    get member_url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('status' => 'connected', 'phone_number' => '5562999999999', 'profile_name' => 'Rhuan')
    expect(response.body).not_to include('never-return', 'backend-only-evolution-key')
    expect(connection.reload.status).to eq('connected')
    expect(WebMock).not_to have_requested(:get, "#{provider_url}/instance/connect/#{instance_name}")
  end

  it 'polls the provider current QR while connecting without recreating the instance' do
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { state: 'connecting' } }.to_json)
    stub_request(:get, "#{provider_url}/instance/fetchInstances").with(query: { instanceName: instance_name })
                                                                 .to_return(headers: json_headers, body: [provider_profile].to_json)
    stub_request(:get, "#{provider_url}/instance/connect/#{instance_name}")
      .to_return(headers: json_headers, body: { base64: qr_code }.to_json)
    get member_url, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('status' => 'connecting', 'qr_code' => qr_code)
    expect(WebMock).not_to have_requested(:post, "#{provider_url}/instance/create")
  end

  it 'returns a normalized error for a status timeout without changing the persisted status' do
    connection.update!(status: 'connected')
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}").to_timeout

    get member_url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:bad_gateway)
    expect(response.parsed_body).to include(
      'error' => 'evolution_unavailable',
      'error_code' => 'unavailable',
      'message' => 'The WhatsApp provider could not complete this operation. Check the connection before trying again.'
    )
    expect(response.parsed_body.dig('connection', 'status')).to eq('connected')
    expect(connection.reload.status).to eq('connected')
  end

  it 'returns a controlled error for an unexpected status payload' do
    connection.update!(status: 'connected')
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(headers: json_headers, body: { unexpected: true }.to_json)

    get member_url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:bad_gateway)
    expect(response.parsed_body['error_code']).to eq('unavailable')
    expect(connection.reload.status).to eq('connected')
  end

  it 'returns a controlled error for an Evolution HTTP failure' do
    connection.update!(status: 'connected')
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(status: 503, headers: json_headers, body: { error: 'provider down' }.to_json)

    get member_url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:bad_gateway)
    expect(response.parsed_body['error']).to eq('evolution_unavailable')
    expect(connection.reload.status).to eq('connected')
  end

  it 'regenerates QR through the verified restart endpoint only when not already connected' do
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { state: 'connecting' } }.to_json)
    stub_request(:post, "#{provider_url}/instance/restart/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { status: 'connecting' } }.to_json)
    stub_request(:get, "#{provider_url}/instance/connect/#{instance_name}")
      .to_return(headers: json_headers, body: { base64: qr_code }.to_json)
    post "#{member_url}/connect", params: { regenerate: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['qr_code']).to eq(qr_code)
    expect(WebMock).to have_requested(:post, "#{provider_url}/instance/restart/#{instance_name}").once
  end

  it 'does not restart a connection that was just connected by scanning the QR' do
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { state: 'open' } }.to_json)
    post "#{member_url}/connect", params: { regenerate: true }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['status']).to eq('connected')
    expect(WebMock).not_to have_requested(:post, "#{provider_url}/instance/restart/#{instance_name}")
  end

  it 'normalizes the provider alternate instance status field instead of reporting false pairing progress' do
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { state: 'close' } }.to_json)
    stub_request(:get, "#{provider_url}/instance/connect/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { status: 'refused' } }.to_json)
    post "#{member_url}/connect", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['status']).to eq('error')
  end

  it 'disconnects using DELETE logout without unlinking or deleting the inbox' do
    connection.update!(inbox: inbox)
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { state: 'open' } }.to_json)
    logout = stub_request(:delete, "#{provider_url}/instance/logout/#{instance_name}")
             .to_return(headers: json_headers, body: { status: 'SUCCESS', error: false }.to_json)
    post "#{member_url}/disconnect", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(connection.reload).to have_attributes(status: 'disconnected', inbox_id: inbox.id)
    expect(logout).to have_been_requested.once
  end

  it 'deletes the provider instance and local record but preserves inbox, other settings and conversations' do
    connection.update!(inbox: inbox)
    inbox.channel.update!(webhook_url: "#{provider_url}/chatwoot/webhook/#{instance_name}",
                          additional_attributes: { 'evolution_instance_name' => instance_name, 'other' => true })
    stub_request(:delete, "#{provider_url}/instance/delete/#{instance_name}")
      .to_return(headers: json_headers, body: { status: 'SUCCESS', error: false }.to_json)

    delete member_url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:no_content)
    expect(WhatsappConnection.exists?(connection.id)).to be(false)
    expect(Inbox.exists?(inbox.id)).to be(true)
    expect(inbox.channel.reload.additional_attributes).to eq('other' => true)
    expect(inbox.channel.webhook_url).to be_nil
  end

  it 'does not clear an inbox configuration that no longer points to the deleted connection' do
    connection.update!(inbox: inbox)
    inbox.channel.update!(additional_attributes: { 'evolution_instance_name' => 'another-manual-instance' })
    stub_request(:delete, "#{provider_url}/instance/delete/#{instance_name}")
      .to_return(headers: json_headers, body: { status: 'SUCCESS', error: false }.to_json)
    delete member_url, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:no_content)
    expect(inbox.channel.reload.additional_attributes['evolution_instance_name']).to eq('another-manual-instance')
  end

  it 'keeps local records and inbox association when remote deletion fails' do
    connection.update!(inbox: inbox)
    stub_request(:delete, "#{provider_url}/instance/delete/#{instance_name}").to_timeout
    delete member_url, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:bad_gateway)
    expect(connection.reload.inbox_id).to eq(inbox.id)
  end

  it 'allows cleanup of a local record if the remote instance is already missing' do
    stub_request(:delete, "#{provider_url}/instance/delete/#{instance_name}").to_return(status: 404)
    delete member_url, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:no_content)
    expect(WhatsappConnection.exists?(connection.id)).to be(false)
  end

  it 'rejects non-boolean QR regeneration parameters before calling the provider' do
    post "#{member_url}/connect", params: { regenerate: 'true' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end

  it 'treats an already-disconnected instance as disconnected without a failing logout request' do
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { state: 'close' } }.to_json)
    post "#{member_url}/disconnect", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['status']).to eq('disconnected')
    expect(WebMock).not_to have_requested(:delete, "#{provider_url}/instance/logout/#{instance_name}")
  end

  it 'detects errors hidden inside a successful provider HTTP response' do
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(headers: json_headers, body: { instance: { state: 'close' } }.to_json)
    stub_request(:get, "#{provider_url}/instance/connect/#{instance_name}")
      .to_return(headers: json_headers, body: { error: true, message: 'backend-only-evolution-key' }.to_json)
    post "#{member_url}/connect", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:bad_gateway)
    expect(connection.reload.status).to eq('disconnected')
    expect(response.body).not_to include('backend-only-evolution-key')
  end

  it 'does not forward credentials to an HTTP redirect' do
    stub_request(:get, "#{provider_url}/instance/connectionState/#{instance_name}")
      .to_return(status: 302, headers: { 'Location' => 'https://another.example.test/steal' })
    post "#{member_url}/connect", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:bad_gateway)
    expect(WebMock).not_to have_requested(:any, /another\.example\.test/)
  end

  it 'keeps existing inbox endpoints working without either Evolution ENV' do
    inbox.channel.update!(additional_attributes: { 'evolution_instance_name' => 'legacy-instance' })
    with_modified_env EVOLUTION_API_URL: nil, EVOLUTION_API_KEY: nil do
      get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['additional_attributes']['evolution_instance_name']).to eq('legacy-instance')
    end
    expect(WebMock).not_to have_requested(:any, /evolution\.example\.test/)
  end
end
