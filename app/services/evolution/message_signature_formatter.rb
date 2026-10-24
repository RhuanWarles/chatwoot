class Evolution::MessageSignatureFormatter
  def self.call(content:, sender_name:, sign_msg:, sign_delimiter:)
    return content unless sign_msg && sender_name.present?

    delimiter = sign_delimiter.presence || "\n"
    delimiter = delimiter.gsub('\\n', "\n")
    signature = "*#{sender_name}:*"
    return content if content.start_with?("#{signature}#{delimiter}")

    [signature, content].join(delimiter)
  end
end
