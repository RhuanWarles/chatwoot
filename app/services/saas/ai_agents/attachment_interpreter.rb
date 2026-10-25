require 'base64'
require 'open3'

class Saas::AiAgents::AttachmentInterpreter
  MAX_FILE_BYTES = 10.megabytes
  MAX_TEXT_CHARS = 12_000
  MAX_IMAGE_BYTES = 8.megabytes
  OOXML_MIME_TYPES = {
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => :docx,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => :xlsx
  }.freeze
  OOXML_EXTENSIONS = { '.docx' => :docx, '.xlsx' => :xlsx }.freeze
  TEXT_MIME_TYPES = %w[
    application/json application/rtf application/xml text/csv text/plain text/rtf text/xml
  ].freeze

  def self.call(message)
    new(message).call
  end

  def initialize(message)
    @message = message
  end

  def call
    parts = @message.attachments.filter_map { |attachment| interpret(attachment) }
    { text: parts.filter_map { |part| part[:text] }.join("\n\n").presence,
      images: parts.filter_map { |part| part[:image] } }
  end

  private

  def interpret(attachment) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return if attachment.audio?

    attached = attachment.file.attached?
    filename = attached ? attachment.file.filename.to_s : attachment.fallback_title.to_s
    mime_type = attached ? attachment.file.content_type.to_s.presence : nil
    mime_type ||= 'image/*' if attachment.image?
    mime_type ||= 'application/octet-stream'
    return image_url_part(attachment, filename) if !attached && attachment.image? && attachment.external_url.present?
    return unsupported_part(filename, mime_type) unless attached
    return unsupported_part(filename, mime_type) if attachment.file.blob.byte_size > MAX_FILE_BYTES

    if attachment.image?
      return image_part(attachment, filename, mime_type) if attachment.file.blob.byte_size <= MAX_IMAGE_BYTES

      return unsupported_part(filename, mime_type, 'imagem excede o limite de interpretação')
    end

    text = extract_text(attachment, filename, mime_type)
    { text: "[Arquivo: #{filename}]\n#{truncate(text.presence || 'Não foi possível extrair texto deste arquivo.')}" }
  rescue StandardError => e
    Rails.logger.warn({ event: 'ai_agent_attachment_interpretation', attachment_id: attachment.id,
                        status: 'failed', error: e.class.name.demodulize.underscore }.to_json)
    unsupported_part(filename, mime_type)
  end

  def image_part(attachment, filename, mime_type)
    data = with_local_file(attachment) { |file| Base64.strict_encode64(file.read) }
    { image: { filename: filename, mime_type: mime_type, data: data },
      text: "[Imagem anexada: #{filename}]" }
  end

  def image_url_part(attachment, filename)
    { image: { filename: filename, url: attachment.external_url }, text: "[Imagem anexada: #{filename}]" }
  end

  def unsupported_part(filename, mime_type, reason = 'formato não suportado')
    { text: "[Arquivo não interpretado: #{filename} (#{mime_type}; #{reason})]" }
  end

  def extract_text(attachment, filename, mime_type)
    return with_local_file(attachment) { |file| file.read.force_encoding(Encoding::UTF_8).scrub } if text_file?(mime_type, filename)
    return extract_pdf(attachment) if mime_type == 'application/pdf' || filename.downcase.end_with?('.pdf')

    ooxml_type = OOXML_MIME_TYPES[mime_type] || OOXML_EXTENSIONS[File.extname(filename).downcase]
    return extract_ooxml(attachment, ooxml_type) if ooxml_type

    ''
  end

  def text_file?(mime_type, filename)
    TEXT_MIME_TYPES.include?(mime_type) || filename.downcase.match?(/\.(txt|csv|json|xml|rtf|md|yaml|yml)$/)
  end

  def extract_pdf(attachment)
    with_local_file(attachment) do |file|
      output, _error, status = Open3.capture3('pdftotext', '-layout', file.path, '-')
      status.success? ? output : ''
    end
  end

  def extract_ooxml(attachment, type)
    with_local_file(attachment) do |file|
      entries, _error, status = Open3.capture3('unzip', '-Z1', file.path)
      return '' unless status.success?

      names = entries.lines.map(&:strip).select { |name| ooxml_entry?(name, type) }
      xml = names.filter_map do |name|
        content, _stderr, entry_status = Open3.capture3('unzip', '-p', file.path, name)
        content if entry_status.success?
      end
      type == :xlsx ? spreadsheet_text(xml) : word_text(xml)
    end
  end

  def ooxml_entry?(name, type)
    return name.match?(%r{\Aword/(document|header|footer)[^/]*\.xml\z}) if type == :docx

    name == 'xl/sharedStrings.xml' || name.match?(%r{\Axl/worksheets/sheet[^/]*\.xml\z})
  end

  def word_text(xml_documents)
    xml_documents.map do |xml|
      document = Nokogiri::XML(xml)
      document.remove_namespaces!
      document.xpath('//t').map(&:text).join(' ')
    end.join("\n").strip
  end

  def spreadsheet_text(xml_documents) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    shared_strings = []
    xml_documents.each do |xml|
      document = Nokogiri::XML(xml)
      document.remove_namespaces!
      next unless document.at_xpath('//sst')

      shared_strings = document.xpath('//si').map { |item| item.xpath('.//t').map(&:text).join }
    end

    xml_documents.filter_map do |xml|
      document = Nokogiri::XML(xml)
      document.remove_namespaces!
      next unless document.at_xpath('//worksheet')

      document.xpath('//row').map do |row|
        row.xpath('./c').map do |cell|
          value = cell.at_xpath('./v')&.text.to_s
          cell['t'] == 's' ? shared_strings[value.to_i].to_s : value
        end.join("\t")
      end.join("\n")
    end.join("\n").strip
  end

  def with_local_file(attachment, &)
    attachment.file.blob.open(&)
  end

  def truncate(text)
    text.to_s.first(MAX_TEXT_CHARS)
  end
end
