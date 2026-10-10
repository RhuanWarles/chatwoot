class Platform::Api::V1::AccountsController < PlatformController
  before_action :protect_ai_entitlements, only: [:create, :update]

  def index
    @resources = @platform_app.platform_app_permissibles
                              .where(permissible_type: 'Account')
                              .includes(:permissible)
                              .map(&:permissible)
  end

  def show; end

  def create
    @resource = Account.create!(account_params)
    update_resource_features
    @resource.save!
    @platform_app.platform_app_permissibles.find_or_create_by(permissible: @resource)
  end

  def update
    @resource.assign_attributes(account_params)
    update_resource_features
    @resource.save!
  end

  def destroy
    DeleteObjectJob.perform_later(@resource)
    head :ok
  end

  private

  def protect_ai_entitlements
    return unless params[:features].is_a?(ActionController::Parameters) && params[:features].keys.intersect?(%w[text_ai voice_ai])

    render json: { error: 'AI access is managed by Super Admin' }, status: :forbidden
  end

  def set_resource
    @resource = Account.find(params[:id])
  end

  def account_params
    permitted_params.except(:features)
  end

  def update_resource_features
    return if permitted_params[:features].blank?

    permitted_params[:features].each do |key, value|
      value.present? ? @resource.enable_features(key) : @resource.disable_features(key)
    end
  end

  def permitted_params
    params.permit(:name, :locale, :domain, :support_email, :status, features: {}, limits: {}, custom_attributes: {})
  end
end
