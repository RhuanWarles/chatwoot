require 'rails_helper'

RSpec.describe 'Account AI entitlements', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:url) { "/api/v1/accounts/#{account.id}" }

  %w[text voice].each do |feature|
    it "blocks all #{feature} agent endpoints and generation when disabled" do
      account.disable_features!("#{feature}_ai")
      resource = feature == 'text' ? 'ai_agents' : 'voice_agents'
      get "#{url}/#{resource}", headers: headers
      expect(response).to have_http_status(:forbidden)
      get "#{url}/#{resource}/123", headers: headers
      expect(response).to have_http_status(:forbidden)
      post "#{url}/#{resource}", params: {}, headers: headers, as: :json
      expect(response).to have_http_status(:forbidden)
      patch "#{url}/#{resource}/123", params: {}, headers: headers, as: :json
      expect(response).to have_http_status(:forbidden)
      delete "#{url}/#{resource}/123", headers: headers
      expect(response).to have_http_status(:forbidden)
      operation = feature == 'text' ? 'text_generations' : 'calls'
      post "#{url}/saas_ai/#{operation}", params: {}, headers: headers, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(Saas::UsageRecord.count).to eq(0)
    end
  end

  [[true, true], [true, false], [false, true], [false, false]].each do |text, voice|
    it "exposes only enabled resources for text=#{text}, voice=#{voice}" do
      account.update!(feature_text_ai: text, feature_voice_ai: voice)
      get "#{url}/saas_ai", headers: headers
      if !text && !voice
        expect(response).to have_http_status(:forbidden)
      else
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expected = []
        expected << 'text_credits' if text
        expected << 'voice_seconds' if voice
        expect(body.fetch('wallets').pluck('resource')).to match_array(expected)
        expect(body.fetch('settings').key?('text_mode')).to be(text)
        expect(body.fetch('settings').key?('inbound_enabled')).to be(voice)
      end
    end
  end

  it 'allows voice settings while blocking text fields, including mixed updates' do
    account.disable_features!(:text_ai)
    patch "#{url}/saas_ai", params: { settings: { inbound_enabled: true } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    patch "#{url}/saas_ai", params: { settings: { text_mode: 'platform', inbound_enabled: false } }, headers: headers, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(account.reload.saas_ai_setting.inbound_enabled).to be(true)
  end

  it 'allows text settings while blocking voice fields' do
    account.disable_features!(:voice_ai)
    patch "#{url}/saas_ai", params: { settings: { text_mode: 'platform' } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    patch "#{url}/saas_ai", params: { settings: { outbound_enabled: true } }, headers: headers, as: :json
    expect(response).to have_http_status(:forbidden)
    get "#{url}/saas_ai/text_generations/999", headers: headers
    expect(response).to have_http_status(:not_found)
    account.disable_features!(:text_ai)
    get "#{url}/saas_ai/text_generations/999", headers: headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'cannot enable AI entitlements through the Account API' do
    account.disable_features!(:text_ai, :voice_ai)
    patch url, params: { name: 'Renamed', feature_text_ai: true, feature_voice_ai: true, features: { text_ai: true, voice_ai: true } },
               headers: headers, as: :json
    expect(account.reload.feature_enabled?(:text_ai)).to be(false)
    expect(account.feature_enabled?(:voice_ai)).to be(false)
  end

  it 'rejects platform API changes to AI access even with an authorized platform token' do
    app = create(:platform_app)
    app.platform_app_permissibles.create!(permissible: account)
    account.disable_features!(:text_ai)
    patch "/platform/api/v1/accounts/#{account.id}", params: { features: { text_ai: true } },
                                                     headers: { api_access_token: app.access_token.token }, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(account.reload.feature_enabled?(:text_ai)).to be(false)
  end

  it 'rejects inbound provider admission while Voice AI is disabled' do
    account.create_saas_ai_setting!(vapi_phone_number_id: 'test-phone')
    account.disable_features!(:voice_ai)
    expect(Saas::VapiClient).not_to receive(:new)
    with_modified_env VAPI_WEBHOOK_SECRET: 'test-secret' do
      post '/webhooks/vapi', params: { message: { type: 'assistant-request', call: {
        id: SecureRandom.uuid, type: 'inboundPhoneCall', phoneNumberId: 'test-phone', customer: { number: '+5562999999999' }
      } } }, headers: { Authorization: 'Bearer test-secret' }, as: :json
    end
    expect(response).to have_http_status(:forbidden)
    expect(account.saas_voice_calls).to be_empty
    expect(account.saas_wallets).to be_empty
  end
end
