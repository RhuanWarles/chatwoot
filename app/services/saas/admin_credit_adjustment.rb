class Saas::AdminCreditAdjustment
  RESOURCES = Saas::Wallet::RESOURCES.freeze
  MAX_REASON_LENGTH = 500

  def self.call(account:, resource:, amount:, reason:, actor:, idempotency_key: nil)
    new(account: account, resource: resource, amount: amount, reason: reason, actor: actor,
        idempotency_key: idempotency_key).call
  end

  def initialize(account:, resource:, amount:, reason:, actor:, idempotency_key: nil)
    @account = account
    @resource = resource
    @direction = amount.is_a?(Integer) && amount.negative? ? 'debit' : 'credit'
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
      'delta_units' => delta_units,
      'original_amount' => @amount,
      'resource' => @resource
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
    raise CustomExceptions::SaasError, 'invalid_amount' unless @amount.is_a?(Integer) && !@amount.zero?
    raise CustomExceptions::SaasError, 'invalid_reason' unless @reason.present? && @reason.length <= MAX_REASON_LENGTH
    raise CustomExceptions::SaasError, 'invalid_actor' unless @actor.is_a?(SuperAdmin)
    raise CustomExceptions::SaasError, 'invalid_reference' unless @idempotency_key.match?(/\A[a-zA-Z0-9_-]{1,100}\z/)
  end

  def units
    @resource == 'voice_seconds' ? @amount.abs * 60 : @amount.abs
  end

  def delta_units
    @direction == 'credit' ? units : -units
  end
end
