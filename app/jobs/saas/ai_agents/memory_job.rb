class Saas::AiAgents::MemoryJob < ApplicationJob
  queue_as :low

  def perform(account_id, agent_id, contact_id, conversation_id, message_id)
    account = Account.find(account_id)
    agent = account.saas_ai_agents.find(agent_id)
    contact = account.contacts.find(contact_id)
    conversation = account.conversations.find(conversation_id)
    Saas::AiAgents::Memory.update!(account: account, agent: agent, contact: contact, conversation: conversation, message_id: message_id)
  end
end
