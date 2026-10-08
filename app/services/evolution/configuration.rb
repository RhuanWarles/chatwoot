class Evolution::Configuration
  def initialize(inbox)
    @inbox = inbox
  end

  def instance_name
    return unless @inbox.api?

    @inbox.channel.additional_attributes['evolution_instance_name'].presence || ENV['EVOLUTION_INSTANCE_NAME'].presence
  end

  def eligible?
    return false unless @inbox.api? && instance_name.present? && ENV['EVOLUTION_API_KEY'].present? && ENV['EVOLUTION_API_URL'].present?
    return true if @inbox.channel.additional_attributes['evolution_instance_name'].present?

    webhook = URI.parse(@inbox.channel.webhook_url.to_s)
    webhook.host == URI.parse(base_url).host && webhook.path.start_with?('/chatwoot/webhook')
  rescue URI::InvalidURIError
    false
  end

  def base_url
    ENV.fetch('EVOLUTION_API_URL').delete_suffix('/')
  end

  def api_key
    ENV.fetch('EVOLUTION_API_KEY')
  end
end
