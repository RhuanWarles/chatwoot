class Saas::Knowledge::Chunking
  CHARACTER_LIMIT = 2400
  OVERLAP = 240
  MAX_CHUNKS = 400

  def self.call(pages)
    chunks = []
    pages.each do |page|
      text = page.fetch(:content).strip
      length = text.length
      offset = 0
      while offset < length
        finish = [offset + CHARACTER_LIMIT, length].min
        finish = word_boundary(text, offset, finish) if finish < length
        content = text[offset...finish].strip
        if content.present?
          chunks << { content: content, position: chunks.length, token_count: (content.length / 4.0).ceil,
                      metadata: { page: page[:page], token_count_estimated: true }.compact }
        end
        raise CustomExceptions::SaasError, 'too_many_chunks' if chunks.length > MAX_CHUNKS
        break if finish >= length

        offset = finish - OVERLAP
      end
    end
    chunks
  end

  def self.word_boundary(text, offset, finish)
    boundary = text.rindex(/\s/, finish)
    boundary && boundary > offset + (CHARACTER_LIMIT / 2) ? boundary : finish
  end
  private_class_method :word_boundary
end
