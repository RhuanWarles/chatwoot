class Saas::AiAgentInbox < ApplicationRecord
  self.table_name = 'saas_ai_agent_inboxes'

  belongs_to :ai_agent, class_name: 'Saas::AiAgent', inverse_of: :ai_agent_inboxes
  belongs_to :inbox

  validates :inbox_id, uniqueness: { scope: :ai_agent_id }
  validate :same_account

  private

  def same_account
    errors.add(:inbox, :invalid) if inbox && ai_agent && inbox.account_id != ai_agent.account_id
  end
end
