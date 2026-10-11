class Saas::AiAgentMemory < ApplicationRecord
  self.table_name = 'saas_ai_agent_memories'

  MAX_CONTENT_LENGTH = 3000

  belongs_to :account
  belongs_to :ai_agent, class_name: 'Saas::AiAgent'
  belongs_to :contact

  validates :content, length: { maximum: MAX_CONTENT_LENGTH }
  validate :scope_matches

  private

  def scope_matches
    errors.add(:ai_agent, :invalid) if ai_agent && ai_agent.account_id != account_id
    errors.add(:contact, :invalid) if contact && contact.account_id != account_id
  end
end
