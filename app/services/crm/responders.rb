# Who answered the customers: the humans who sent public replies and the AI. A person who owns a deal is not
# necessarily the one who answers its conversations, so this is a different question from the deal owner.
module Crm::Responders
  # A message from a person has no "generated_by_ai" key at all. Without the COALESCEs the condition is NULL for it (not
  # false), and NOT (NULL) is NULL too, so no person's reply would ever match "by humans" and every reply would look AI.
  AI_CONDITION = "COALESCE((messages.content_attributes #>> '{}')::json ->> 'generated_by_ai', '') = 'true' " \
                 "OR COALESCE(messages.sender_type, '') IN ('AgentBot', 'Captain::Assistant', 'Saas::AiAgent')".freeze

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
