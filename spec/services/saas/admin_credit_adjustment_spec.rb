require 'rails_helper'

RSpec.describe Saas::AdminCreditAdjustment do
  let(:account) { create(:account) }
  let(:actor) { create(:super_admin) }

  [100, -100].each do |amount|
    it "applies signed text adjustment #{amount} to a balance of 400" do
      wallet = Saas::Wallet.for_account(account, 'text_credits')
      wallet.credit!(units: 400, reference: 'initial')
      record = described_class.call(account: account, resource: 'text_credits', amount: amount, reason: 'Correction', actor: actor)
      expect(wallet.reload.balance_units).to eq(400 + amount)
      expect(record.metadata).to include('original_amount' => amount, 'resource' => 'text_credits', 'actor_id' => actor.id)
      expect(record.reference).to start_with('admin_adjustment:')
    end
  end

  it 'rejects -351 when a balance of 400 has 50 reserved' do
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 400, reference: 'initial')
    wallet.reserve!(units: 50, reference: 'pending')
    expect do
      described_class.call(account: account, resource: 'text_credits', amount: -351, reason: 'Correction', actor: actor)
    end.to raise_error(CustomExceptions::SaasError, 'insufficient_balance')
    expect(wallet.reload.available_units).to eq(350)
    expect(wallet.balance_units).to eq(400)
    expect(wallet.usage_records.count).to eq(2)
  end

  it 'removes ten minutes from a balance of 400 minutes using seconds' do
    wallet = Saas::Wallet.for_account(account, 'voice_seconds')
    wallet.credit!(units: 400 * 60, reference: 'initial')
    record = described_class.call(account: account, resource: 'voice_seconds', amount: -10, reason: 'Correction', actor: actor)
    expect(wallet.reload.balance_units).to eq(390 * 60)
    expect(record.units).to eq(600)
    expect(record.metadata).to include('original_amount' => -10, 'delta_units' => -600)
  end

  it 'adds text credits and records the reason and actor' do
    record = described_class.call(account: account, resource: 'text_credits', amount: 10,
                                  reason: 'Créditos iniciais', actor: actor)

    expect(record.wallet.balance_units).to eq(10)
    expect(record.metadata).to include('reason' => 'Créditos iniciais', 'actor_id' => actor.id, 'delta_units' => 10)
  end

  it 'converts voice minutes to seconds' do
    record = described_class.call(account: account, resource: 'voice_seconds', amount: 5,
                                  reason: 'Pacote de voz', actor: actor)

    expect(record.units).to eq(300)
    expect(record.wallet.balance_units).to eq(300)
  end

  it 'removes credits without touching reserved units' do
    described_class.call(account: account, resource: 'text_credits', amount: 10,
                         reason: 'Carga inicial', actor: actor)

    record = described_class.call(account: account, resource: 'text_credits', amount: -3,
                                  reason: 'Correção manual', actor: actor)

    expect(record.metadata).to include('delta_units' => -3)
    expect(record.wallet.reload.balance_units).to eq(7)
  end

  it 'does not duplicate a repeated request with the same idempotency key' do
    args = { account: account, resource: 'text_credits', amount: 4, reason: 'Carga', actor: actor, idempotency_key: 'form-123' }

    first = described_class.call(**args)
    second = described_class.call(**args)

    expect(second.id).to eq(first.id)
    expect(first.wallet.reload.balance_units).to eq(4)
  end

  it 'does not allow a debit to consume reserved units' do
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 10, reference: 'test:credit')
    wallet.reserve!(units: 8, reference: 'test:reservation')

    expect do
      described_class.call(account: account, resource: 'text_credits', amount: -3,
                           reason: 'Ajuste', actor: actor)
    end.to raise_error(CustomExceptions::SaasError, 'insufficient_balance')
  end

  it 'requires a reason and a nonzero amount' do
    expect do
      described_class.call(account: account, resource: 'text_credits', amount: 0, reason: ' ', actor: actor)
    end.to raise_error(CustomExceptions::SaasError, 'invalid_amount')

    expect do
      described_class.call(account: account, resource: 'text_credits', amount: 1, reason: ' ', actor: actor)
    end.to raise_error(CustomExceptions::SaasError, 'invalid_reason')
  end
end
