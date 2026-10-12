class Saas::KnowledgeChunk < ApplicationRecord
  belongs_to :account
  belongs_to :knowledge_document, class_name: 'Saas::KnowledgeDocument'
  has_neighbors :embedding
  validates :content, :embedding, presence: true
  validate :account_matches_document

  private

  def account_matches_document
    errors.add(:account, :invalid) unless account_id == knowledge_document.knowledge_base.account_id
  end
end
