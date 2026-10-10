require 'rails_helper'

RSpec.describe Saas::AdminCreditAdjustment do
  let(:account) { create(:account) }
  let(:actor) { create(:super_admin) }

  it 'adds text credits and records the reason and actor' do
    record = described_class.call(account:, resource: 'text_credits', direction: 'credit', amount: 10,
                                  reason: 'Créditos iniciais', actor:)

    expect(record.wallet.balance_units).to eq(10)
    expect(record.metadata).to include('reason' => 'Créditos iniciais', 'actor_id' => actor.id, 'delta_units' => 10)
  end

  it 'converts voice minutes to seconds' do
    record = described_class.call(account:, resource: 'voice_seconds', direction: 'credit', amount: 5,
                                  reason: 'Pacote de voz', actor:)

    expect(record.units).to eq(300)
    expect(record.wallet.balance_units).to eq(300)
  end

  it 'removes credits without touching reserved units' do
    described_class.call(account:, resource: 'text_credits', direction: 'credit', amount: 10,
                         reason: 'Carga inicial', actor:)

    record = described_class.call(account:, resource: 'text_credits', direction: 'debit', amount: 3,
                                  reason: 'Correção manual', actor:)

    expect(record.metadata).to include('delta_units' => -3)
    expect(record.wallet.reload.balance_units).to eq(7)
  end

  it 'does not duplicate a repeated request with the same idempotency key' do
    args = { account:, resource: 'text_credits', direction: 'credit', amount: 4, reason: 'Carga', actor:, idempotency_key: 'form-123' }

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
      described_class.call(account:, resource: 'text_credits', direction: 'debit', amount: 3,
                           reason: 'Ajuste', actor:)
    end.to raise_error(CustomExceptions::SaasError, 'insufficient_balance')
  end

  it 'requires a reason and a positive amount' do
    expect do
      described_class.call(account:, resource: 'text_credits', direction: 'credit', amount: 0, reason: ' ', actor:)
    end.to raise_error(CustomExceptions::SaasError, 'invalid_amount')

    expect do
      described_class.call(account:, resource: 'text_credits', direction: 'credit', amount: 1, reason: ' ', actor:)
    end.to raise_error(CustomExceptions::SaasError, 'invalid_reason')
  end
end
