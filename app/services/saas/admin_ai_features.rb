class Saas::AdminAiFeatures
  FEATURES = %w[text voice].freeze

  def self.call(account:, feature:, enabled:, actor:)
    unless FEATURES.include?(feature) && [true, false].include?(enabled) && actor.is_a?(SuperAdmin)
      raise CustomExceptions::SaasError, 'invalid_settings'
    end

    account.with_lock do
      previous = account.feature_enabled?("#{feature}_ai")
      next if previous == enabled

      history = account.internal_attributes.fetch('ai_feature_history', []).dup
      history << { 'account_id' => account.id, 'feature' => feature, 'previous' => previous, 'enabled' => enabled,
                   'actor_id' => actor.id, 'actor_email' => actor.email, 'at' => Time.current.iso8601 }
      account.public_send("feature_#{feature}_ai=", enabled)
      account.update!(internal_attributes: account.internal_attributes.merge('ai_feature_history' => history))
    end
  end
end
