class Saas::KnowledgeDocument < ApplicationRecord
  MAX_TEXT_LENGTH = 500_000
  MAX_FILE_SIZE = 10.megabytes
  MAX_DOCUMENTS = 100
  belongs_to :knowledge_base, class_name: 'Saas::KnowledgeBase'
  has_many :chunks, class_name: 'Saas::KnowledgeChunk', dependent: :destroy
  has_one_attached :file
  validates :name, presence: true, length: { maximum: 200 }
  validates :source_type, inclusion: { in: %w[manual txt md pdf] }
  validates :status, inclusion: { in: %w[processing ready failed] }
  validates :content, length: { maximum: MAX_TEXT_LENGTH }
  validates :indexing_version, presence: true
  after_commit :enqueue_indexing, on: [:create, :update], if: :saved_change_to_indexing_version?

  def reindex!(attributes = {})
    with_lock do
      update!(attributes.merge(status: 'processing', error_code: nil, indexing_version: SecureRandom.uuid))
    end
  end

  def public_data(detailed: false)
    data = attributes.slice('id', 'name', 'source_type', 'status', 'error_code', 'indexed_at', 'created_at', 'updated_at', 'checksum')
    data['chunks_count'] = chunks.size
    data['content'] = content if detailed
    data
  end

  private

  def enqueue_indexing
    Saas::Knowledge::IndexJob.perform_later(id, indexing_version)
  end
end
