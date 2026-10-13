class Saas::AiAgents::MessageSplitter
  MAX_MESSAGES = 8
  MAX_CHUNK_DELAY_SECONDS = 0.8

  def self.call(content, split_response_messages)
    new(content, split_response_messages).call
  end

  def initialize(content, split_response_messages)
    @content = content.to_s
    @split_response_messages = ActiveModel::Type::Boolean.new.cast(split_response_messages)
  end

  def call
    return [@content] unless @split_response_messages

    parts = @content.split(/\n\s*\n+/).map(&:strip).reject(&:blank?)
    return [@content] if parts.length <= 1
    return parts if parts.length <= MAX_MESSAGES

    parts.first(MAX_MESSAGES - 1) + [parts.drop(MAX_MESSAGES - 1).join("\n\n")]
  end

  def self.delay_for(index)
    [0.4 + (index * 0.1), MAX_CHUNK_DELAY_SECONDS].min
  end
end
