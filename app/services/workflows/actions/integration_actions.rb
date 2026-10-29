class Workflows::Actions::IntegrationActions
  NAMES = %w[http_request set_variable].freeze
  BODYLESS_METHODS = %w[get delete].freeze
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15
  MAX_RESPONSE_BYTES = 1.megabyte
  RESPONSE_PREVIEW_BYTES = 500
  TOO_LARGE_PREVIEW = '(response too large to show)'.freeze

  def initialize(context, _workflow)
    @context = context
  end

  # SafeFetch refuses private and internal addresses, so a workflow cannot be used to reach the installation's network.
  def http_request(params)
    verb = params['method'].to_s.downcase.presence || 'post'
    body = BODYLESS_METHODS.include?(verb) ? nil : request_body(params)
    { 'url' => params['url'], 'method' => verb.upcase, 'response' => fetch_preview(verb, params['url'].to_s, body, request_headers(params, body)) }
  end

  def set_variable(params)
    raise ArgumentError, 'variable name is required' if params['name'].blank?

    @context.vars[params['name'].to_s] = params['value']
    { 'name' => params['name'], 'value' => params['value'] }
  end

  private

  def fetch_preview(verb, url, body, headers)
    preview = nil
    SafeFetch.fetch(url, method: verb, body: body, headers: headers, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT,
                         max_bytes: MAX_RESPONSE_BYTES, validate_content_type: false) do |result|
      preview = result.tempfile.read(RESPONSE_PREVIEW_BYTES)&.force_encoding(Encoding::UTF_8)&.scrub
    end
    preview
  rescue SafeFetch::FileTooLargeError
    # The other system already got the call; only its answer is too big to keep.
    TOO_LARGE_PREVIEW
  end

  def request_body(params)
    ActiveModel::Type::Boolean.new.cast(params['include_payload']) ? @context.payload.to_json : params['body'].presence
  end

  def request_headers(params, body)
    headers = Array(params['headers']).to_h { |item| [item['key'].to_s.strip, item['value'].to_s] }.compact_blank
    headers['Content-Type'] = 'application/json' if body.present? && headers.keys.none? { |name| name.casecmp?('content-type') }
    headers
  end
end
