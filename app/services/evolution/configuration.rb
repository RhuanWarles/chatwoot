class Evolution::Configuration
  def self.available?
    ENV['EVOLUTION_API_URL'].present? && ENV['EVOLUTION_API_KEY'].present?
  end

  def initialize(inbox = nil, connection: nil)
    @inbox = inbox
    @connection = connection || inbox&.whatsapp_connection
  end

  def instance_name
    return @connection.instance_name if @connection&.instance_name.present?
    return unless @inbox&.api?

    @inbox.channel.additional_attributes['evolution_instance_name'].presence || ENV['EVOLUTION_INSTANCE_NAME'].presence
  end

  def eligible?
    return false unless provider_available?
    return true if @connection.present?
    return false unless @inbox&.api?

    legacy_instance_configured? || matching_webhook?
  rescue URI::InvalidURIError
    false
  end

  def base_url
    ENV.fetch('EVOLUTION_API_URL').delete_suffix('/')
  end

  def api_key
    ENV.fetch('EVOLUTION_API_KEY')
  end

  private

  def provider_available?
    instance_name.present? && self.class.available?
  end

  def legacy_instance_configured?
    @inbox.channel.additional_attributes['evolution_instance_name'].present?
  end

  def matching_webhook?
    webhook = URI.parse(@inbox.channel.webhook_url.to_s)
    webhook.host == URI.parse(base_url).host && webhook.path.start_with?('/chatwoot/webhook')
  end
end
