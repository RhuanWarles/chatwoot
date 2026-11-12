class Api::V1::Accounts::GeneralDashboardController < Api::V1::Accounts::BaseController
  before_action -> { authorize :report, :view? }

  rescue_from ArgumentError do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def show
    render json: Dashboards::Overview.new(Current.account, params).perform
  end
end
