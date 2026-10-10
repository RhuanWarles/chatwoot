class Saas::VoiceService
  def initialize(account)
    @account = account
  end

  def reserve!(direction:, request_id:, customer_number:, contact: nil, provider_call_id: nil)
    @account.reload.require_ai_feature!(:voice)
    wallet = Saas::Wallet.for_account(@account, 'voice_seconds')
    wallet.with_lock do
      existing = @account.saas_voice_calls.find_by(request_id: request_id)
      if existing
        raise CustomExceptions::SaasError, 'reference_conflict' unless existing.direction == direction && existing.customer_number == customer_number

        next existing
      end

      settings = eligible_settings(direction)
      seconds = [wallet.available_units, settings.max_call_seconds].min
      raise CustomExceptions::SaasError, 'insufficient_balance' if seconds < Saas::AiSetting::MIN_CALL_SECONDS

      usage = wallet.reserve!(units: seconds, reference: "voice:#{request_id}")
      @account.saas_voice_calls.create!(
        direction: direction, request_id: request_id, customer_number: customer_number, contact: contact,
        provider_call_id: provider_call_id, usage_record: usage, max_duration_seconds: seconds,
        assistant_id: settings.vapi_assistant_id, phone_number_id: settings.vapi_phone_number_id
      )
    end
  end

  def complete!(call, duration_seconds:, ended_reason:, summary: nil, transcript: nil)
    wallet = call.usage_record.wallet
    wallet.with_lock do
      call.lock!
      next call if call.status == 'ended'

      # The customer is never billed beyond the duration authorized at admission.
      billed_seconds = [duration_seconds, call.max_duration_seconds].min
      wallet.settle!(call.usage_record, units: billed_seconds, metadata: { duration_seconds: duration_seconds })
      call.update!(status: 'ended', duration_seconds: duration_seconds, ended_reason: ended_reason,
                   summary: summary, transcript: transcript)
      call
    end
  end

  private

  def eligible_settings(direction)
    settings = @account.saas_ai_setting
    unless @account.active? && settings&.voice_ready? && settings.public_send("#{direction}_enabled")
      raise CustomExceptions::SaasError, 'voice_not_ready'
    end

    settings
  end
end
