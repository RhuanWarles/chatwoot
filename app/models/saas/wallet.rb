class Saas::Wallet < ApplicationRecord
  RESOURCES = %w[text_credits voice_seconds].freeze

  belongs_to :account
  has_many :usage_records, class_name: 'Saas::UsageRecord', dependent: :destroy

  validates :resource, inclusion: { in: RESOURCES }, uniqueness: { scope: :account_id }
  validates :balance_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.for_account(account, resource)
    account.with_lock { account.saas_wallets.find_or_create_by!(resource: resource) }
  end

  def available_units
    balance_units - usage_records.where(status: 'reserved').sum(:reserved_units)
  end

  # Only trusted provisioning/billing code calls this method, never account APIs.
  def credit!(units:, reference:, metadata: {})
    raise ArgumentError, 'units must be a positive integer' unless units.is_a?(Integer) && units.positive?

    with_lock do
      existing = usage_records.find_by(reference: reference)
      if existing
        raise CustomExceptions::SaasError, 'reference_conflict' unless existing.kind == 'credit' && existing.units == units

        next existing
      end
      update!(balance_units: balance_units + units)
      usage_records.create!(reference: reference, kind: 'credit', status: 'settled', units: units, metadata: metadata)
    end
  end

  def debit!(units:, reference:, metadata: {})
    raise ArgumentError, 'units must be a positive integer' unless units.is_a?(Integer) && units.positive?

    with_lock do
      existing = usage_records.find_by(reference: reference)
      if existing
        raise CustomExceptions::SaasError, 'reference_conflict' unless existing.kind == 'adjustment' && existing.units == units

        next existing
      end
      raise CustomExceptions::SaasError, 'insufficient_balance' if available_units < units

      update!(balance_units: balance_units - units)
      usage_records.create!(reference: reference, kind: 'adjustment', status: 'settled', units: units,
                            metadata: metadata)
    end
  end

  def reserve!(units:, reference:, expires_at: nil, metadata: {})
    raise ArgumentError, 'units must be a positive integer' unless units.is_a?(Integer) && units.positive?

    with_lock do
      existing = usage_records.find_by(reference: reference)
      if existing
        raise CustomExceptions::SaasError, 'reference_conflict' unless existing.kind == 'consumption' && existing.reserved_units == units

        if existing.status == 'released'
          raise CustomExceptions::SaasError, 'insufficient_balance' if available_units < units

          existing.update!(status: 'reserved', expires_at: expires_at, metadata: metadata)
        end
        next existing
      end
      raise CustomExceptions::SaasError, 'insufficient_balance' if available_units < units

      usage_records.create!(reference: reference, kind: 'consumption', status: 'reserved', reserved_units: units,
                            expires_at: expires_at, metadata: metadata)
    end
  end

  def settle!(record, units:, metadata: {})
    raise ArgumentError, 'units must be a nonnegative integer' unless units.is_a?(Integer) && units >= 0

    with_lock do
      record = usage_records.find(record.id)
      next record unless record.status == 'reserved'

      raise ArgumentError, 'usage exceeds reservation' if units > record.reserved_units

      update!(balance_units: balance_units - units)
      record.update!(status: 'settled', units: units, metadata: metadata)
      record
    end
  end

  def release!(record, metadata: {})
    with_lock do
      record = usage_records.find(record.id)
      record.update!(status: 'released', metadata: record.metadata.merge(metadata)) if record.status == 'reserved'
    end
  end

  def self.release_expired!(now: Time.current)
    Saas::UsageRecord.joins(:wallet).where(status: 'reserved').where('expires_at IS NOT NULL AND expires_at <= ?', now)
                     .where(saas_wallets: { resource: 'text_credits' }).find_each do |record|
      record.wallet.with_lock do
        record.reload
        next unless record.status == 'reserved' && record.expires_at && record.expires_at <= now

        record.update!(status: 'released')
      end
    end
  end

  def public_data
    reserved = usage_records.where(status: 'reserved').sum(:reserved_units)
    { resource: resource, balance_units: balance_units, reserved_units: reserved, available_units: balance_units - reserved }
  end
end
