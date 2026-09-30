class Saas::VapiEventService
  def initialize(message)
    @message = message
    @provider_call = message.fetch('call')
  end

  def perform
    return incoming_call if @message['type'] == 'assistant-request'

    call = find_call
    return {} unless call

    if @message['type'] == 'end-of-call-report'
      Saas::VoiceService.new(call.account).complete!(
        call, duration_seconds: duration_seconds, ended_reason: @message['endedReason'],
              summary: @message.dig('analysis', 'summary'), transcript: @message.dig('artifact', 'transcript')
      )
    elsif %w[queued ringing in-progress].include?(@message['status'])
      call.with_lock { call.update!(status: @message['status']) unless %w[ended failed].include?(call.status) }
    end
    {}
  end

  private

  def incoming_call
    raise CustomExceptions::SaasError, 'invalid_event' unless @provider_call['type'] == 'inboundPhoneCall'

    settings = Saas::AiSetting.find_by!(vapi_phone_number_id: @provider_call.fetch('phoneNumberId'))
    number = @provider_call.dig('customer', 'number')
    raise CustomExceptions::SaasError, 'invalid_phone' unless number.is_a?(String) && number.match?(/\A\+[1-9]\d{6,14}\z/)

    call = Saas::VoiceService.new(settings.account).reserve!(
      direction: 'inbound', request_id: @provider_call.fetch('id'), provider_call_id: @provider_call.fetch('id'),
      customer_number: number, contact: settings.account.contacts.find_by(phone_number: number)
    )
    { assistantId: call.assistant_id, assistantOverrides: Saas::VapiClient.new.assistant_overrides(call) }
  end

  def find_call
    call = Saas::VoiceCall.find_by(provider_call_id: @provider_call.fetch('id'))
    # The creation callback may arrive before the outbound HTTP response.
    call ||= Saas::VoiceCall.find_by(id: @provider_call.dig('metadata', 'saas_call_id'))
    return unless call && call.phone_number_id == @provider_call['phoneNumberId']

    call.with_lock do
      raise CustomExceptions::SaasError, 'invalid_event' if call.provider_call_id.present? && call.provider_call_id != @provider_call['id']

      call.update!(provider_call_id: @provider_call['id'])
    end
    call
  end

  def duration_seconds
    duration = @message.fetch('durationSeconds') { duration_from_timestamps }
    raise CustomExceptions::SaasError, 'invalid_duration' unless duration.is_a?(Numeric) && duration.finite? && duration >= 0

    duration.ceil
  rescue ArgumentError, TypeError
    raise CustomExceptions::SaasError, 'invalid_duration'
  end

  def duration_from_timestamps
    started = @message['startedAt'] || @provider_call['startedAt']
    return 0 if started.nil?

    ended = @message['endedAt'] || @provider_call['endedAt']
    Time.iso8601(ended) - Time.iso8601(started)
  end
end
