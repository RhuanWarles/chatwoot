require 'rails_helper'
require Rails.root.join('db/migrate/20261010020000_enable_existing_account_ai_features').to_s

RSpec.describe EnableExistingAccountAiFeatures do
  it 'enables existing accounts without changing previous flags, wallets or agents' do
    account = create(:account)
    account.disable_features!(:text_ai, :voice_ai)
    account.enable_features!(:inbox_management, :api_and_webhooks)
    original_flags = account.feature_flags
    original_extended_flags = account.feature_flags_ext_1
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 400, reference: 'initial')
    agent = account.saas_ai_agents.create!(name: 'Saved', system_prompt: 'Help', provider: 'openai', model: 'test', active: true)

    described_class.new.up

    expect(account.reload.feature_enabled?(:text_ai)).to be(true)
    expect(account.feature_enabled?(:voice_ai)).to be(true)
    expect(account.feature_flags).to eq(original_flags)
    expect(account.feature_flags_ext_1).to eq(original_extended_flags | described_class::AI_FEATURE_MASK)
    expect(wallet.reload.balance_units).to eq(400)
    expect(agent.reload.active).to be(true)
  end
end
