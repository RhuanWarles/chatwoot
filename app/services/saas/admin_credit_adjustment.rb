class Saas::AdminCreditAdjustment
  RESOURCES = Saas::Wallet::RESOURCES.freeze
  DIRECTIONS = %w[credit debit].freeze
  MAX_REASON_LENGTH = 500

  def self.call(account:, resource:, direction:, amount:, reason:, actor:, idempotency_key: nil)
    new(account: account, resource: resource, direction: direction, amount: amount, reason: reason, actor: actor,
        idempotency_key: idempotency_key).call
  end

  def initialize(account:, resource:, direction:, amount:, reason:, actor:, idempotency_key: nil)
    @account = account
    @resource = resource
    @direction = direction
    @amount = amount
    @reason = reason.to_s.strip
    @actor = actor
    @idempotency_key = idempotency_key.to_s.presence || SecureRandom.uuid
  end

  def call
    validate!

    wallet = Saas::Wallet.for_account(@account, @resource)
    reference = "admin_adjustment:#{@idempotency_key}"
    metadata = {
      'source' => 'super_admin',
      'direction' => @direction,
      'reason' => @reason,
      'actor_id' => @actor.id,
      'actor_email' => @actor.email,
      'delta_units' => delta_units
    }

    if @direction == 'credit'
      wallet.credit!(units: units, reference: reference, metadata: metadata)
    else
      wallet.debit!(units: units, reference: reference, metadata: metadata)
    end
  end

  private

  def validate!
    raise CustomExceptions::SaasError, 'invalid_resource' unless RESOURCES.include?(@resource)
    raise CustomExceptions::SaasError, 'invalid_direction' unless DIRECTIONS.include?(@direction)
    raise CustomExceptions::SaasError, 'invalid_amount' unless @amount.is_a?(Integer) && @amount.positive?
    raise CustomExceptions::SaasError, 'invalid_reason' unless @reason.present? && @reason.length <= MAX_REASON_LENGTH
    raise CustomExceptions::SaasError, 'invalid_actor' unless @actor
    raise CustomExceptions::SaasError, 'invalid_reference' unless @idempotency_key.match?(/\A[a-zA-Z0-9_-]{1,100}\z/)
  end

  def units
    @resource == 'voice_seconds' ? @amount * 60 : @amount
  end

  def delta_units
    @direction == 'credit' ? units : -units
  end
end
