class Api::V1::Accounts::Crm::AutoCardSettingsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: Crm::AutoCardSettings.new(Current.account)
  end

  def update
    attributes = params.require(:auto_card_settings)
    settings = Crm::AutoCardSettings.new(Current.account)
    settings.update!(enabled: attributes[:enabled], pipeline_id: attributes[:pipeline_id], stage_id: attributes[:stage_id])
    render json: settings
  rescue Crm::AutoCardSettings::Invalid => e
    render json: { message: e.message }, status: :unprocessable_entity
  end
end
