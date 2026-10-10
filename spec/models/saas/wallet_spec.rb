require 'rails_helper'
require 'timeout'

RSpec.describe Saas::Wallet do
  self.use_transactional_tests = false

  let(:account) { create(:account) }
  let(:wallet) { described_class.for_account(account, 'text_credits') }

  after { account.destroy! }

  it 'restores a released reservation when balance remains available without duplicating the reference' do
    wallet.credit!(units: 10, reference: 'grant')
    original = wallet.reserve!(units: 5, reference: 'request-a')
    wallet.release!(original)

    restored = wallet.reserve!(units: 5, reference: 'request-a')
    repeated = wallet.reserve!(units: 5, reference: 'request-a')

    expect([restored.id, repeated.id]).to eq([original.id, original.id])
    expect(original.reload.status).to eq('reserved')
    expect(wallet.available_units).to eq(5)
    expect(wallet.usage_records.where(reference: 'request-a').count).to eq(1)
  end

  it 'refuses to restore a reservation after another request reserves the balance' do
    wallet.credit!(units: 5, reference: 'grant')
    original = wallet.reserve!(units: 5, reference: 'request-a')
    wallet.release!(original)
    other = wallet.reserve!(units: 5, reference: 'request-b')

    expect { wallet.reserve!(units: 5, reference: 'request-a') }.to raise_error do |error|
      expect(error.class.name).to eq('CustomExceptions::SaasError')
      expect(error.code).to eq('insufficient_balance')
    end
    expect(original.reload).to have_attributes(status: 'released', reserved_units: 5, units: 0)
    expect(other.reload.status).to eq('reserved')
    expect(wallet.available_units).to eq(0)

    wallet.settle!(other, units: 5)
    expect { wallet.reserve!(units: 5, reference: 'request-a') }.to raise_error do |error|
      expect(error.code).to eq('insufficient_balance')
    end
    expect(wallet.reload.balance_units).to eq(0)
  end

  it 'does not reactivate or debit an already settled reservation on retry' do
    wallet.credit!(units: 5, reference: 'grant')
    record = wallet.reserve!(units: 5, reference: 'request-a')
    wallet.settle!(record, units: 5)
    repeated = wallet.reserve!(units: 5, reference: 'request-a')
    wallet.settle!(repeated, units: 5)
    wallet.release!(repeated)

    expect(repeated.reload).to have_attributes(status: 'settled', units: 5)
    expect(wallet.reload.balance_units).to eq(0)
    expect(wallet.available_units).to eq(0)
  end

  it 'releases only expired text reservations and keeps voice and future reservations intact' do
    wallet.credit!(units: 10, reference: 'grant')
    expired = wallet.reserve!(units: 2, reference: 'expired', expires_at: 1.minute.ago)
    future = wallet.reserve!(units: 2, reference: 'future', expires_at: 1.hour.from_now)
    voice = described_class.for_account(account, 'voice_seconds')
    voice.credit!(units: 10, reference: 'voice-grant')
    voice_record = voice.reserve!(units: 2, reference: 'voice', expires_at: 1.minute.ago)

    2.times { described_class.release_expired! }

    expect(expired.reload.status).to eq('released')
    expect(future.reload.status).to eq('reserved')
    expect(voice_record.reload.status).to eq('reserved')
    expect(wallet.reload.available_units).to eq(8)
  end

  it 'rechecks expiration under the wallet lock when a selected reservation has been renewed' do
    wallet.credit!(units: 5, reference: 'grant')
    record = wallet.reserve!(units: 5, reference: 'renewed', expires_at: 1.minute.ago)
    candidates = Saas::UsageRecord.joins(:wallet).where(status: 'reserved')
                                 .where('expires_at IS NOT NULL AND expires_at <= ?', Time.current)
                                 .where(saas_wallets: { resource: 'text_credits' })
    allow(Saas::UsageRecord).to receive(:joins).with(:wallet).and_return(candidates)
    allow(candidates).to receive(:where).and_return(candidates)
    allow(candidates).to receive(:find_each).and_yield(record)
    wallet.release!(record)
    wallet.reserve!(units: 5, reference: 'renewed', expires_at: 1.hour.from_now)

    described_class.release_expired!

    expect(record.reload.status).to eq('reserved')
    expect(wallet.available_units).to eq(0)
  end

  it 'serializes concurrent restoration and reservation against the same balance' do
    wallet.credit!(units: 5, reference: 'concurrent-grant')
    original = wallet.reserve!(units: 5, reference: 'concurrent-a')
    wallet.release!(original)
    wallet_id = wallet.id
    ready = Queue.new
    start = Queue.new
    threads = %w[concurrent-a concurrent-b].map do |reference|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          described_class.find(wallet_id).reserve!(units: 5, reference: reference)
          :reserved
        rescue CustomExceptions::SaasError => error
          error.code
        end
      end
    end
    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { start << true }

    expect(Timeout.timeout(10) { threads.map(&:value) }).to contain_exactly(:reserved, 'insufficient_balance')
    expect(wallet.reload.available_units).to eq(0)
    expect(wallet.usage_records.where(status: 'reserved').sum(:reserved_units)).to eq(5)
  ensure
    2.times { start << true } if start
    threads&.each(&:join)
  end
end
