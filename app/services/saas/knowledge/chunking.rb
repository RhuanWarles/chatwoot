class Saas::Knowledge::Chunking
  CHARACTER_LIMIT = Saas::KnowledgeBase::DEFAULT_CHUNK_SIZE
  OVERLAP = Saas::KnowledgeBase::DEFAULT_CHUNK_OVERLAP
  MAX_CHUNKS = 400

  def self.call(pages, chunk_size: CHARACTER_LIMIT, chunk_overlap: OVERLAP)
    raise CustomExceptions::SaasError, 'invalid_chunk_settings' unless chunk_size.to_i >= 400 && chunk_overlap.to_i >= 0 && chunk_overlap.to_i < chunk_size.to_i

    chunks = []
    pages.each do |page|
      text = page.fetch(:content).strip
      length = text.length
      offset = 0
      while offset < length
        finish = [offset + chunk_size.to_i, length].min
        finish = word_boundary(text, offset, finish, chunk_size.to_i) if finish < length
        content = text[offset...finish].strip
        if content.present?
          chunks << { content: content, position: chunks.length, token_count: (content.length / 4.0).ceil,
                      metadata: { page: page[:page], token_count_estimated: true }.compact }
        end
        raise CustomExceptions::SaasError, 'too_many_chunks' if chunks.length > MAX_CHUNKS
        break if finish >= length

        offset = finish - chunk_overlap.to_i
      end
    end
    chunks
  end

  def self.word_boundary(text, offset, finish, chunk_size)
    boundary = text.rindex(/\s/, finish)
    boundary && boundary > offset + (chunk_size / 2) ? boundary : finish
  end
  private_class_method :word_boundary
end
