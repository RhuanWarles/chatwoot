require 'rails_helper'

RSpec.describe 'Super Admin AI management', type: :request do
  let(:account) { create(:account) }
  let(:actor) { create(:super_admin) }
  let(:url) { "/super_admin/accounts/#{account.id}/saas_features" }

  it 'requires Super Admin authentication' do
    sign_in(create(:user, account: account, role: :administrator))
    post url, params: { feature: 'text', enabled: 'false' }
    expect(response).to have_http_status(:redirect)
    expect(account.reload.feature_enabled?(:text_ai)).to be(true)
  end

  it 'shows independent switches, signed amount inputs and both balances even when disabled' do
    sign_in(actor, scope: :super_admin)
    account.disable_features!(:voice_ai)
    get "/super_admin/accounts/#{account.id}/saas_usage"
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css('input[role="switch"]').count).to eq(2)
    expect(document.css('select[name="direction"]')).to be_empty
    expect(document.css('input[name="amount"]').count).to eq(2)
    expect(document.css('input[name="amount"][min]')).to be_empty
    expect(response.body).to include('Text AI', 'Voice AI', 'Disabled')
  end

  %w[text voice].each do |feature|
    context "with #{feature} agents" do
      let(:agent) do
        if feature == 'text'
          account.saas_ai_agents.create!(name: 'Larissa', system_prompt: 'Help', provider: 'openai', model: 'test', active: true)
        else
          account.saas_voice_agents.create!(name: 'Voice', provider: 'vapi', active: true)
        end
      end
      let(:wallet) { Saas::Wallet.for_account(account, feature == 'text' ? 'text_credits' : 'voice_seconds') }

      before do
        sign_in(actor, scope: :super_admin)
        agent
        wallet.credit!(units: 400, reference: 'initial')
      end

      it 'requires confirmation and preserves the active agent and balance' do
        post url, params: { feature: feature, enabled: 'false' }
        expect(response).to have_http_status(:ok)
        expect(account.reload.feature_enabled?("#{feature}_ai")).to be(true)
        expect(response.body).to include('confirmed')
        post url, params: { feature: feature, enabled: 'false', confirmed: 'true' }
        expect(account.reload.feature_enabled?("#{feature}_ai")).to be(false)
        expect(agent.reload.active).to be(true)
        expect(wallet.reload.balance_units).to eq(400)
        expect(account.internal_attributes.fetch('ai_feature_history').last).to include(
          'actor_id' => actor.id, 'feature' => feature, 'previous' => true, 'enabled' => false
        )
      end

      it 'reenables access without recreating agents or balances and displays the audit history' do
        post url, params: { feature: feature, enabled: 'false', confirmed: 'true' }
        post url, params: { feature: feature, enabled: 'true' }
        expect(account.reload.feature_enabled?("#{feature}_ai")).to be(true)
        expect(agent.reload.active).to be(true)
        expect(wallet.reload.balance_units).to eq(400)
        get "/super_admin/accounts/#{account.id}/saas_usage"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(actor.email)
      end
    end
  end

  it 'rejects malformed feature settings without changing entitlements' do
    sign_in(actor, scope: :super_admin)
    post url, params: { feature: 'text', enabled: '0' }
    expect(account.reload.feature_enabled?(:text_ai)).to be(true)
    expect(flash[:alert]).to be_present
  end

  it 'preserves AI access when the general feature form tries to bypass the audited action' do
    sign_in(actor, scope: :super_admin)
    account.disable_features!(:text_ai)
    patch "/super_admin/accounts/#{account.id}", params: {
      account: { name: account.name, locale: account.locale, status: account.status },
      enabled_features: { feature_text_ai: 'true', feature_voice_ai: 'false', feature_agent_management: 'true' }
    }
    expect(response).to have_http_status(:redirect)
    expect(account.reload.feature_enabled?(:text_ai)).to be(false)
    expect(account.feature_enabled?(:voice_ai)).to be(true)
    expect(account.internal_attributes).not_to have_key('ai_feature_history')
  end

  it 'interprets the amount sign at the request boundary and rejects zero and decimals' do
    sign_in(actor, scope: :super_admin)
    adjustment = "/super_admin/accounts/#{account.id}/saas_usage_adjust"
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 400, reference: 'initial')
    post adjustment, params: { resource: 'text_credits', amount: '-100', reason: 'Correction' }
    expect(wallet.reload.balance_units).to eq(300)
    %w[0 1.5].each do |amount|
      post adjustment, params: { resource: 'text_credits', amount: amount, reason: 'Correction' }
      expect(flash[:alert]).to be_present
      expect(wallet.reload.balance_units).to eq(300)
    end
  end
end
