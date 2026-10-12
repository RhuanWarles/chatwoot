require 'digest'

class Saas::Knowledge::IndexJob < ApplicationJob
  queue_as :default

  def perform(id, version)
    @version = version
    document = Saas::KnowledgeDocument.find_by(id: id, indexing_version: version)
    return unless document

    pages, content = extract(document)
    attributes = { content: content, checksum: Digest::SHA256.hexdigest(content), embedding_model: Saas::Knowledge::Embeddings.model }
    index_document(document, pages, attributes)
  rescue StandardError => e
    code = e.respond_to?(:code) ? e.code : 'indexing_failed'
    # Conditional SQL keeps a deleted document or newer edit from being changed by a stale job.
    # rubocop:disable Rails/SkipsModelValidations
    Saas::KnowledgeDocument.where(id: id, indexing_version: version).update_all(status: 'failed', error_code: code, updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    Rails.logger.warn({ event: 'knowledge_indexing', document_id: id, status: 'failed', error_code: code }.to_json)
  end

  private

  def extract(document)
    pages = Saas::Knowledge::Extraction.call(document)
    content = pages.map { |page| page.fetch(:content) }.join("\n").strip
    raise CustomExceptions::SaasError, 'no_extractable_text' if content.blank?
    raise CustomExceptions::SaasError, 'text_too_large' unless content.valid_encoding? && content.length <= Saas::KnowledgeDocument::MAX_TEXT_LENGTH

    [pages, content]
  end

  def index_document(document, pages, attributes)
    if document.checksum == attributes[:checksum] && document.embedding_model == attributes[:embedding_model] && document.chunks.exists?
      document.with_lock { document.update!(status: 'ready', error_code: nil) if document.indexing_version == @version }
      return
    end

    chunks = Saas::Knowledge::Chunking.call(pages)
    vectors = chunks.each_slice(32).flat_map do |batch|
      Saas::Knowledge::Embeddings.call(account: document.knowledge_base.account, texts: batch.pluck(:content),
                                       source: 'knowledge_embedding', document_id: document.id)
    end
    replace_chunks(document, chunks, vectors, attributes)
  end

  def replace_chunks(document, chunks, vectors, attributes)
    document.with_lock do
      return unless document.indexing_version == @version

      document.chunks.destroy_all
      chunks.each_with_index do |chunk, index|
        document.chunks.create!(chunk.merge(account_id: document.knowledge_base.account_id, embedding: vectors.fetch(index)))
      end
      document.update!(attributes.merge(indexed_at: Time.current, status: 'ready', error_code: nil))
    end
  end
end
