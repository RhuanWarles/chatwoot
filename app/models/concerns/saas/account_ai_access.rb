module Saas::AccountAiAccess
  extend ActiveSupport::Concern

  included do
    before_create :enable_default_ai_features
  end

  def require_ai_feature!(feature)
    raise CustomExceptions::SaasError, "#{feature}_ai_disabled" unless feature_enabled?("#{feature}_ai")
  end

  def saas_ai_credit_status
    text_mode = saas_ai_setting&.text_mode || 'platform'
    available_text_credits = saas_wallets.find_by(resource: 'text_credits')&.available_units || 0
    active_text_ai_agents = saas_ai_agents.where(active: true).count

    {
      text_mode: text_mode,
      available_text_credits: available_text_credits,
      active_text_ai_agents: active_text_ai_agents,
      show_credit_warning: ai_credit_warning?(text_mode, available_text_credits, active_text_ai_agents)
    }
  end

  private

  def enable_default_ai_features
    enable_features(:text_ai, :voice_ai)
  end

  def ai_credit_warning?(text_mode, available_text_credits, active_text_ai_agents)
    feature_enabled?(:text_ai) && text_mode == 'platform' && available_text_credits <= 0 && active_text_ai_agents.positive?
  end
end
