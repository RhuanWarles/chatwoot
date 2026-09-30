class Webhooks::VapiController < ActionController::API
  before_action :authenticate_vapi!

  def create
    message = params.require(:message)
    unless message.is_a?(ActionController::Parameters) && message[:call].is_a?(ActionController::Parameters) &&
           message.dig(:call, :id).is_a?(String) && message.dig(:call, :id).match?(/\A[0-9a-f-]{36}\z/i)
      return render json: { error: 'invalid_event' }, status: :unprocessable_entity
    end

    return render json: {} unless %w[assistant-request status-update end-of-call-report].include?(message[:type])

    render json: Saas::VapiEventService.new(message.to_unsafe_h).perform
  rescue CustomExceptions::SaasError => e
    render json: { error: e.code }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound, KeyError, ActionController::ParameterMissing
    render json: { error: 'invalid_event' }, status: :unprocessable_entity
  end

  private

  def authenticate_vapi!
    expected = ENV.fetch('VAPI_WEBHOOK_SECRET')
    token = request.authorization.to_s.delete_prefix('Bearer ')
    head :unauthorized unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, token)
  end
end
