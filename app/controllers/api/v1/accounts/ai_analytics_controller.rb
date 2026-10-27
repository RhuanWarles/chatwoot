class Api::V1::Accounts::AiAnalyticsController < Api::V1::Accounts::BaseController
  include SaasAiAccess
  before_action -> { require_ai_feature('text') }
  before_action :check_admin_authorization?

  rescue_from ArgumentError do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def show
    render json: Saas::AiAnalytics.new(Current.account, params).perform
  end

  def replies
    render json: Crm::ResponderReport.new(Current.account, params).perform
  end
end
