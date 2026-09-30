class Saas::VapiClient
  API_URL = 'https://api.vapi.ai'.freeze
  CONFIG_KEYS = %w[VAPI_PRIVATE_KEY VAPI_WEBHOOK_SECRET VAPI_WEBHOOK_URL].freeze

  def self.configured?
    CONFIG_KEYS.all? { |key| ENV[key].present? }
  end

  def self.server_config
    { url: ENV.fetch('VAPI_WEBHOOK_URL'), headers: { 'Authorization' => "Bearer #{ENV.fetch('VAPI_WEBHOOK_SECRET')}" } }
  end

  def create_call(call)
    request(:post, '/call', {
              assistantId: call.assistant_id,
              phoneNumberId: call.phone_number_id,
              customer: { number: call.customer_number },
              metadata: { saas_call_id: call.id },
              assistantOverrides: assistant_overrides(call)
            })
  end

  def get_call(id)
    request(:get, "/call/#{id}")
  end

  def configure_phone(id)
    request(:patch, "/phone-number/#{id}", { assistantId: nil, server: self.class.server_config })
  end

  def assistant_overrides(call)
    {
      maxDurationSeconds: call.max_duration_seconds,
      serverMessages: %w[end-of-call-report status-update],
      server: self.class.server_config
    }
  end

  private

  def request(method, path, body = nil)
    connection = Faraday.new(url: API_URL) do |builder|
      builder.request :json
      builder.response :json
      builder.response :raise_error
      builder.options.open_timeout = 5
      builder.options.timeout = 20
    end
    connection.headers['Authorization'] = "Bearer #{ENV.fetch('VAPI_PRIVATE_KEY')}"
    connection.public_send(method, path, body).body
  end
end
