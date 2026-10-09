require 'rails_helper'

RSpec.describe Saas::AiAgents::RespondJob do
  it 'rejects a conversation outside the supplied account' do
    account = create(:account)
    conversation = create(:conversation)
    message = create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox)
    expect(Saas::AiAgents::Respond).not_to receive(:new)
    described_class.perform_now(account.id, conversation.id, message.id)
  end

  it 'registers specific transient and busy retries after the general discard handler' do
    handlers = described_class.rescue_handlers.map(&:first)
    expect(handlers.index('CustomExceptions::AiAgentError::Transient')).to be > handlers.index('CustomExceptions::AiAgentError')
    expect(handlers.index('CustomExceptions::AiAgentError::Busy')).to be > handlers.index('CustomExceptions::AiAgentError')
  end
end
