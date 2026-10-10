module SaasAiAccess
  extend ActiveSupport::Concern

  private

  def require_ai_feature(feature)
    return if Current.account.feature_enabled?("#{feature}_ai")

    render json: { error: "#{feature}_ai_disabled" }, status: :forbidden
  end
end
