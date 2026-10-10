require 'rails_helper'

RSpec.describe Account do
  describe '#saas_ai_credit_status' do
    let(:account) { create(:account) }
    let!(:setting) { account.create_saas_ai_setting! }
    let!(:agent) do
      account.saas_ai_agents.create!(name: 'Larissa', system_prompt: 'Answer clearly', provider: 'openai', model: 'gpt-4.1', active: true)
    end
    let!(:wallet) { account.saas_wallets.create!(resource: 'text_credits', balance_units: balance) }
    let(:balance) { 0 }

    subject(:status) { account.reload.saas_ai_credit_status }

    it 'shows the warning when platform credits are exhausted and a text agent is active' do
      expect(status).to include(
        text_mode: 'platform',
        available_text_credits: 0,
        active_text_ai_agents: 1,
        show_credit_warning: true
      )
    end

    it 'does not show the warning when credits are available' do
      wallet.update!(balance_units: 1)

      expect(status[:show_credit_warning]).to be(false)
    end

    it 'uses available credits after subtracting reservations' do
      wallet.update!(balance_units: 1)
      wallet.usage_records.create!(reference: 'pending', kind: 'consumption', status: 'reserved', reserved_units: 1)

      expect(status).to include(available_text_credits: 0, show_credit_warning: true)
    end

    it 'does not show the warning for BYOK or without an active agent' do
      setting.update_columns(text_mode: 'byok')
      expect(status[:show_credit_warning]).to be(false)

      agent.update!(active: false)
      setting.update!(text_mode: 'platform')
      expect(status[:show_credit_warning]).to be(false)
    end
  end
end
