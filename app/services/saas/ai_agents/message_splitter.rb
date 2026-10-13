class Saas::AiAgents::MessageSplitter
  MIN_SPLIT_LENGTH = 240
  MAX_CHUNK_DELAY_SECONDS = 0.8

  def self.call(content, maximum)
    new(content, maximum).call
  end

  def initialize(content, maximum)
    @content = content.to_s.strip
    @maximum = maximum.to_i.clamp(1, 5)
  end

  def call
    return [@content] if @content.blank? || @maximum == 1 || @content.length < MIN_SPLIT_LENGTH

    parts = split_paragraphs
    parts = split_sentences(parts) if parts.length == 1 && !list_content?
    parts = merge_parts(parts)
    parts.first(@maximum).reject(&:blank?)
  end

  def self.delay_for(index)
    [0.4 + (index * 0.1), MAX_CHUNK_DELAY_SECONDS].min
  end

  private

  def split_paragraphs
    @content.split(/\n{2,}/).map(&:strip).reject(&:blank?)
  end

  def split_sentences(parts)
    parts.flat_map { |part| part.split(/(?<=[.!?])\s+(?=[A-ZÀ-ÖØ-Þ0-9])/).map(&:strip) }.reject(&:blank?)
  end

  def list_content?
    @content.lines.count >= 2 && @content.lines.count { |line| line.match?(/^\s*(?:[-*•]|\d+[.)])\s+/) } >= 2
  end

  def merge_parts(parts)
    return parts if parts.length <= @maximum

    groups = Array.new(@maximum) { [] }
    parts.each_with_index { |part, index| groups[index * @maximum / parts.length] << part }
    groups.map { |group| group.join("\n\n") }.reject(&:blank?)
  end
end
