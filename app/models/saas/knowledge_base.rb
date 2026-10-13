class Saas::KnowledgeBase < ApplicationRecord
  DEFAULT_SIMILARITY_THRESHOLD = 0.35
  LEGACY_SIMILARITY_THRESHOLD = 0.5
  DEFAULT_RETRIEVAL_TOP_K = 5
  DEFAULT_CHUNK_SIZE = 2400
  DEFAULT_CHUNK_OVERLAP = 240

  belongs_to :account
  has_many :documents, class_name: 'Saas::KnowledgeDocument', dependent: :destroy
  has_many :agent_links, class_name: 'Saas::AiAgentKnowledgeBase', dependent: :destroy
  has_many :agents, through: :agent_links, source: :ai_agent
  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2000 }
  validates :active, inclusion: { in: [true, false] }
  validates :similarity_threshold, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :retrieval_top_k, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 10 }, allow_nil: true
  validates :chunk_size, numericality: { only_integer: true, greater_than_or_equal_to: 400, less_than_or_equal_to: 10_000 }, allow_nil: true
  validates :chunk_overlap, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :chunk_overlap_is_smaller_than_chunk_size

  after_initialize :apply_new_record_defaults, if: :new_record?
  after_update_commit :reindex_documents_after_chunking_change

  def effective_similarity_threshold
    similarity_threshold || LEGACY_SIMILARITY_THRESHOLD
  end

  def effective_retrieval_top_k
    retrieval_top_k || DEFAULT_RETRIEVAL_TOP_K
  end

  def effective_chunk_size
    chunk_size || DEFAULT_CHUNK_SIZE
  end

  def effective_chunk_overlap
    chunk_overlap || DEFAULT_CHUNK_OVERLAP
  end

  def public_data
    attributes.slice('id', 'name', 'description', 'active', 'created_at', 'updated_at', 'similarity_threshold',
                     'retrieval_top_k', 'chunk_size', 'chunk_overlap').merge(
      'effective_similarity_threshold' => effective_similarity_threshold,
      'effective_retrieval_top_k' => effective_retrieval_top_k,
      'effective_chunk_size' => effective_chunk_size,
      'effective_chunk_overlap' => effective_chunk_overlap,
      'documents_count' => documents.count, 'agents' => agents.map { |agent| { id: agent.id, name: agent.name } }
    )
  end

  private

  def apply_new_record_defaults
    self.similarity_threshold = DEFAULT_SIMILARITY_THRESHOLD if similarity_threshold.nil?
    self.retrieval_top_k = DEFAULT_RETRIEVAL_TOP_K if retrieval_top_k.nil?
    self.chunk_size = DEFAULT_CHUNK_SIZE if chunk_size.nil?
    self.chunk_overlap = DEFAULT_CHUNK_OVERLAP if chunk_overlap.nil?
  end

  def reindex_documents_after_chunking_change
    return unless saved_change_to_chunk_size? || saved_change_to_chunk_overlap?

    documents.find_each(&:reindex!)
  end

  def chunk_overlap_is_smaller_than_chunk_size
    return if chunk_overlap.blank? || chunk_size.blank? || chunk_overlap < chunk_size

    errors.add(:chunk_overlap, :less_than, count: chunk_size)
  end
end
