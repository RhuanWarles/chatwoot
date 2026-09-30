class Saas::StartVoiceCallJob < ApplicationJob
  queue_as :default

  def perform(call_id)
    call = Saas::VoiceCall.find(call_id)
    claimed = call.with_lock do
      next false unless call.status == 'pending'

      call.update!(status: 'submitting')
      true
    end
    return unless claimed

    result = Saas::VapiClient.new.create_call(call)
    call.with_lock do
      call.update!(provider_call_id: result.fetch('id'))
      call.update!(status: 'queued') if call.status == 'submitting'
    end
  rescue Faraday::ClientError
    reject_call(call)
  rescue Faraday::Error, KeyError
    # A timeout/5xx may have created a call. Never retry or refund blindly.
    call.with_lock do
      call.update!(status: 'unknown', ended_reason: 'provider_outcome_unknown') if call.status == 'submitting'
    end
  end

  private

  def reject_call(call)
    # A rejected request did not start a call; release its reserved minutes.
    call.usage_record.wallet.with_lock do
      call.lock!
      if call.status == 'submitting'
        call.usage_record.wallet.release!(call.usage_record)
        call.update!(status: 'failed', ended_reason: 'provider_rejected')
      end
    end
  end
end
