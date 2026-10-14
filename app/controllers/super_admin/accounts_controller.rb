class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  before_action :validate_suspension_metadata, only: :update

  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  # def scoped_resource
  #   if current_user.super_admin?
  #     resource_class
  #   else
  #     resource_class.with_less_stuff
  #   end
  # end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def resource_params
    permitted_params = super
    permitted_params.extract!(:suspension_category, :suspension_reason)
    permitted_params[:limits] = permitted_params[:limits].to_h.compact if permitted_params.key?(:limits)
    permitted_params[:captain_models] = permitted_params[:captain_models].to_h.compact_blank.presence if permitted_params.key?(:captain_models)
    if params[:enabled_features].present?
      # AI access changes use the dedicated, audited action with disable confirmation.
      permitted_params[:selected_feature_flags] = selected_flags_with_preserved_ai_access
    end
    permitted_params
  end

  def update
    apply_suspension_metadata
    super
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def saas_usage
    @saas_account = requested_resource
    @saas_wallets = Saas::Wallet::RESOURCES.index_with do |resource|
      Saas::Wallet.for_account(@saas_account, resource)
    end
    @saas_usage_records = Saas::UsageRecord.where(wallet: @saas_wallets.values)
                                           .includes(:wallet).order(created_at: :desc).limit(100)
    @ai_usage_period = params[:period].presence_in(%w[today seven_days thirty_days total]) || 'thirty_days'
    @ai_usage_source = params[:source].presence_in(%w[runtime playground memory])
    @ai_usage_provider = params[:provider].presence
    @ai_usage_model = params[:model].presence
    @ai_usage_agent_id = params[:agent_id].presence
    @ai_usage_scope = Saas::UsageRecord.where(account: @saas_account, kind: 'consumption').where(source: %w[runtime playground memory])
    @ai_usage_scope = @ai_usage_scope.where(source: @ai_usage_source) if @ai_usage_source
    @ai_usage_scope = @ai_usage_scope.where(provider: @ai_usage_provider) if @ai_usage_provider
    @ai_usage_scope = @ai_usage_scope.where(model: @ai_usage_model) if @ai_usage_model
    @ai_usage_scope = @ai_usage_scope.where("metadata ->> 'ai_agent_id' = ?", @ai_usage_agent_id) if @ai_usage_agent_id
    @ai_usage_scope = @ai_usage_scope.where(created_at: usage_period_range(@ai_usage_period)) if @ai_usage_period != 'total'
    @ai_usage_summary = @ai_usage_scope.group(:source).pluck(
      :source, Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(prompt_tokens), 0)'),
      Arel.sql('COALESCE(SUM(completion_tokens), 0)'), Arel.sql('COALESCE(SUM(total_tokens), 0)'),
      Arel.sql('COALESCE(SUM(estimated_cost_usd), 0)'), Arel.sql('COALESCE(SUM(units), 0)')
    ).to_h { |row| [row[0], { generations: row[1], prompt_tokens: row[2], completion_tokens: row[3],
                              total_tokens: row[4], estimated_cost_usd: row[5], credits: row[6] }] }
    page = params[:page].to_s.match?(/\A[1-9]\d*\z/) ? params[:page].to_i : 1
    per_page = params[:per_page].to_s.presence_in(%w[25 50])&.to_i || 25
    @ai_usage_records = @ai_usage_scope.includes(:wallet).order(created_at: :desc, id: :desc).page(page).per(per_page)
    @ai_usage_agents = @saas_account.saas_ai_agents.order(:name)
  end

  def saas_usage_adjust
    Saas::AdminCreditAdjustment.call(
      account: requested_resource,
      resource: params[:resource],
      amount: parse_amount,
      reason: params[:reason],
      actor: current_super_admin,
      idempotency_key: params[:idempotency_key]
    )
    redirect_to saas_usage_super_admin_account_path(requested_resource), notice: I18n.t('super_admin.saas_usage.adjustment_success')
  rescue CustomExceptions::SaasError => e
    error_message = I18n.t("super_admin.saas_usage.errors.#{e.code}", default: I18n.t('super_admin.saas_usage.errors.invalid'))
    redirect_to saas_usage_super_admin_account_path(requested_resource), alert: error_message
  rescue ActiveRecord::RecordInvalid
    redirect_to saas_usage_super_admin_account_path(requested_resource), alert: I18n.t('super_admin.saas_usage.errors.invalid')
  end

  def saas_features
    feature, enabled = ai_feature_params
    if !enabled && active_ai_agents?(feature) && params[:confirmed] != 'true'
      @saas_account = requested_resource
      @ai_feature = feature
      render :saas_feature_confirmation
      return
    end

    Saas::AdminAiFeatures.call(account: requested_resource, feature: feature, enabled: enabled, actor: current_super_admin)
    redirect_to saas_usage_super_admin_account_path(requested_resource), notice: I18n.t('super_admin.saas_usage.features.saved')
  rescue CustomExceptions::SaasError
    redirect_to saas_usage_super_admin_account_path(requested_resource), alert: I18n.t('super_admin.saas_usage.errors.invalid')
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  private

  def selected_flags_with_preserved_ai_access
    ai_flags = %i[feature_text_ai feature_voice_ai]
    chosen = params[:enabled_features].keys.map(&:to_sym) - ai_flags
    chosen + (requested_resource.selected_feature_flags & ai_flags)
  end

  def ai_feature_params
    unless Saas::AdminAiFeatures::FEATURES.include?(params[:feature]) && %w[true false].include?(params[:enabled])
      raise CustomExceptions::SaasError, 'invalid_settings'
    end

    [params[:feature], params[:enabled] == 'true']
  end

  def active_ai_agents?(feature)
    agents = feature == 'text' ? requested_resource.saas_ai_agents : requested_resource.saas_voice_agents
    agents.exists?(active: true)
  end

  def parse_amount
    value = params[:amount].to_s
    raise CustomExceptions::SaasError, 'invalid_amount' unless value.match?(/\A-?[1-9]\d*\z/)

    value.to_i
  end

  def usage_period_range(period)
    case period
    when 'today' then Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    when 'seven_days' then 7.days.ago..Time.zone.now
    when 'thirty_days' then 30.days.ago..Time.zone.now
    else Time.at(0)..Time.zone.now
    end
  end

  def validate_suspension_metadata
    return unless suspension_metadata_required?

    validate_suspension_category
    validate_suspension_reason
    return if requested_resource.errors.empty?

    requested_resource.assign_attributes(resource_params.except(:manually_managed_features))
    render :edit,
           locals: { page: Administrate::Page::Form.new(dashboard, requested_resource) },
           status: :unprocessable_entity
  end

  def validate_suspension_category
    if suspension_details[:category].blank?
      requested_resource.errors.add(:suspension_category, :blank)
    elsif Account::SUSPENSION_CATEGORIES.exclude?(suspension_details[:category])
      requested_resource.errors.add(:suspension_category, :inclusion)
    end
  end

  def validate_suspension_reason
    if suspension_details[:reason].blank?
      requested_resource.errors.add(:suspension_reason, :blank)
    elsif suspension_details[:reason].length > 256
      requested_resource.errors.add(:suspension_reason, :too_long, count: 256)
    end
  end

  def suspension_metadata_required?
    return false unless target_status == 'suspended'

    requested_resource.active? ||
      requested_resource.suspension_history.present? ||
      suspension_details.values.any?(&:present?)
  end

  def apply_suspension_metadata
    return unless target_status == 'suspended'

    history = suspension_history_with_changes
    return if history.blank?

    requested_resource.internal_attributes = requested_resource.internal_attributes.merge('suspensions' => history)
  end

  def suspension_history_with_changes
    history = requested_resource.suspension_history.map(&:dup)
    return history << new_suspension_event.merge('suspended_by' => current_super_admin.id) if requested_resource.active?
    return append_legacy_suspension(history) if history.empty?
    return unless suspension_metadata_changed?(history.last)

    history.tap { |events| events[-1] = events.last.merge(suspension_details.stringify_keys) }
  end

  def append_legacy_suspension(history)
    return if suspension_details.values.none?(&:present?)

    history << new_suspension_event
  end

  def new_suspension_event
    suspension_details.stringify_keys.merge('suspended_at' => Time.current.iso8601)
  end

  def suspension_metadata_changed?(latest_suspension)
    latest_suspension.values_at('category', 'reason') != suspension_details.values_at(:category, :reason)
  end

  def suspension_details
    @suspension_details ||= {
      category: params.dig(:account, :suspension_category).to_s,
      reason: params.dig(:account, :suspension_reason).to_s.strip
    }
  end

  def target_status
    params.dig(:account, :status).to_s
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')
