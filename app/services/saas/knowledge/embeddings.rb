class Saas::Knowledge::Embeddings
  DIMENSIONS = 1536

  def self.model
    ENV.fetch('SAAS_EMBEDDING_MODEL', 'text-embedding-3-small')
  end

  def self.call(account:, texts:, source:, document_id: nil, agent_id: nil)
    provider = ENV.fetch('SAAS_EMBEDDING_PROVIDER', 'openai')
    record = Saas::UsageRecord.create!(account: account, reference: "#{source}:#{SecureRandom.uuid}", kind: 'consumption',
                                       source: source, status: 'running', units: 0, reserved_units: 0,
                                       provider: provider, model: model,
                                       metadata: { 'knowledge_document_id' => document_id, 'ai_agent_id' => agent_id }.compact)
    client = configured_client(provider)
    response = client.embeddings(parameters: { model: model, input: texts, dimensions: DIMENSIONS, encoding_format: 'float' })
    vectors = parse_vectors(response, texts.size)
    tokens = response.fetch('usage', {}).fetch('total_tokens', 0)
    record.update!(status: 'completed', prompt_tokens: tokens, completion_tokens: 0, total_tokens: tokens)
    vectors
  rescue StandardError => e
    record&.update!(status: 'failed', error_code: e.respond_to?(:code) ? e.code : 'embedding_failed')
    raise CustomExceptions::SaasError, 'embedding_failed', cause: nil
  end

  def self.configured_client(provider)
    key = ENV.fetch('SAAS_EMBEDDING_API_KEY', nil).presence ||
          (ENV.fetch('SAAS_TEXT_API_KEY', nil) if ENV.fetch('SAAS_TEXT_PROVIDER', nil) == 'openai')
    unless provider == 'openai' && key.present? && %w[text-embedding-3-small text-embedding-3-large].include?(model)
      raise CustomExceptions::SaasError, 'embedding_not_configured'
    end

    OpenAI::Client.new(access_token: key, request_timeout: 30, log_errors: false)
  end

  def self.parse_vectors(response, count)
    vectors = response.fetch('data').sort_by { |item| item.fetch('index') }.map { |item| item.fetch('embedding') }
    valid = vectors.size == count && vectors.all? { |vector| valid_vector?(vector) }
    raise CustomExceptions::SaasError, 'invalid_embedding_response' unless valid

    vectors
  end

  def self.valid_vector?(vector)
    vector.size == DIMENSIONS && vector.all? { |number| number.is_a?(Numeric) && number.finite? }
  end
  private_class_method :configured_client, :parse_vectors, :valid_vector?
end
