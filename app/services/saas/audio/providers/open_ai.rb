class Saas::Audio::Providers::OpenAi
  TIMEOUT = 60

  def initialize(api_key:, model:)
    @model = model
    @client = OpenAI::Client.new(access_token: api_key, request_timeout: TIMEOUT, log_errors: false)
  end

  def transcribe(blob:)
    temp_file = Tempfile.new(['saas-audio', extension_for(blob.content_type)])
    blob.open { |source| IO.copy_stream(source, temp_file) }
    temp_file.rewind
    response = @client.audio.transcribe(parameters: { model: @model, file: temp_file, temperature: 0.0 })
    response.fetch('text').to_s.strip
  ensure
    temp_file&.close!
  end

  private

  def extension_for(content_type)
    ".#{content_type.to_s.split('/').last.to_s.split(';').first}".delete_suffix('.')
  end
end
