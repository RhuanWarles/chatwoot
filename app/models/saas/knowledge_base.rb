class Saas::KnowledgeBase < ApplicationRecord
  belongs_to :account
  has_many :documents, class_name: 'Saas::KnowledgeDocument', dependent: :destroy
  has_many :agent_links, class_name: 'Saas::AiAgentKnowledgeBase', dependent: :destroy
  has_many :agents, through: :agent_links, source: :ai_agent
  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2000 }
  validates :active, inclusion: { in: [true, false] }

  def public_data
    attributes.slice('id', 'name', 'description', 'active', 'created_at', 'updated_at').merge(
      'documents_count' => documents.count, 'agents' => agents.map { |agent| { id: agent.id, name: agent.name } }
    )
  end
end
