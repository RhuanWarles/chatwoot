class Saas::Audio::Providers::OpenAi
  TIMEOUT = 60
  ENDPOINT = '/audio/transcriptions'.freeze
  OGG_CONTENT_TYPES = %w[audio/ogg audio/opus].freeze
  MPEG_CONTENT_TYPES = %w[audio/mpeg audio/mp3].freeze

  attr_reader :request_metadata

  def initialize(api_key:, model:)
    @model = model
    @client = OpenAI::Client.new(access_token: api_key, request_timeout: TIMEOUT, log_errors: false)
  end

  def transcribe(blob:)
    extension = extension_for(blob)
    temp_file = Tempfile.new(['saas-audio', extension])
    blob.open { |source| IO.copy_stream(source, temp_file) }
    temp_file.rewind
    upload = Saas::Audio::Providers::MultipartUpload.new(
      temp_file, filename: "audio#{extension}", content_type: content_type_for(blob)
    )
    @request_metadata = {
      endpoint: ENDPOINT, method: 'POST', model: @model, field: 'file', filename: upload.original_filename,
      content_type: upload.content_type, byte_size: temp_file.size, parameters: { temperature: 0.0 }
    }
    response = @client.audio.transcribe(parameters: { model: @model, file: upload, temperature: 0.0 })
    response.fetch('text').to_s.strip
  ensure
    temp_file&.close!
  end

  private

  def extension_for(blob)
    return '.ogg' if ogg_content_type?(blob.content_type)
    return '.mp3' if mpeg_content_type?(blob.content_type) || mpeg_filename?(blob.filename)

    extension = File.extname(blob.filename.to_s).downcase
    return extension if extension.present?

    ".#{blob.content_type.to_s.split('/').last.to_s.split(';').first}".delete_suffix('.')
  end

  def content_type_for(blob)
    return 'audio/ogg' if ogg_content_type?(blob.content_type)
    return 'audio/mpeg' if mpeg_content_type?(blob.content_type) || mpeg_filename?(blob.filename)

    blob.content_type.presence || 'application/octet-stream'
  end

  def ogg_content_type?(content_type)
    OGG_CONTENT_TYPES.include?(content_type.to_s.split(';').first)
  end

  def mpeg_content_type?(content_type)
    MPEG_CONTENT_TYPES.include?(content_type.to_s.split(';').first)
  end

  def mpeg_filename?(filename)
    %w[.mp3 .mpga].include?(File.extname(filename.to_s).downcase)
  end
end
