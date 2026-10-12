class Saas::AiAgentKnowledgeBase < ApplicationRecord
  belongs_to :ai_agent, class_name: 'Saas::AiAgent'
  belongs_to :knowledge_base, class_name: 'Saas::KnowledgeBase'
  validates :knowledge_base_id, uniqueness: { scope: :ai_agent_id }
  validate :same_account

  private

  def same_account
    errors.add(:knowledge_base, :invalid) unless ai_agent.account_id == knowledge_base.account_id
  end
end
