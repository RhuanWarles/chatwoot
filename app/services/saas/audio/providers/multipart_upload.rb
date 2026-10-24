class Saas::Audio::Providers::MultipartUpload
  attr_reader :content_type, :original_filename

  def initialize(io, filename:, content_type:)
    @io = io
    @original_filename = filename
    @content_type = content_type
  end

  def length
    @io.size
  end

  def read(*)
    @io.read(*)
  end

  def rewind
    @io.rewind
  end
end
