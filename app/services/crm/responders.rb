# Who answered the customers: the humans who sent public replies and the AI. A person who owns a deal is not
# necessarily the one who answers its conversations, so this is a different question from the deal owner.
module Crm::Responders
  AI_CONDITION = "(messages.content_attributes #>> '{}')::json ->> 'generated_by_ai' = 'true' " \
                 "OR messages.sender_type IN ('AgentBot', 'Captain::Assistant', 'Saas::AiAgent')".freeze

  # Public replies written for the customer, from any conversation of the account.
  def self.replies(account)
    Message.where(account_id: account.id, message_type: :outgoing, private: false)
  end

  def self.by_ai(scope)
    scope.where(AI_CONDITION)
  end

  def self.by_humans(scope)
    scope.where(sender_type: 'User').where.not(AI_CONDITION)
  end
end
