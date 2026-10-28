require 'rails_helper'

RSpec.describe Saas::AiAgents::RespondJob do
  it 'checks an updated blacklist before reading attachments in a previously queued response' do
    account = create(:account)
    conversation = create(:conversation, account: account)
    conversation.contact_inbox.update!(source_id: '120363123456789@g.us')
    message = create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                               content_attributes: { participant: '5562999991111@s.whatsapp.net' })
    account.saas_ai_agents.build.configure!(
      { name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true,
        respond_to_groups: true, group_response_blacklist: ['5562999991111'] }, selected_inboxes: [conversation.inbox]
    )
    expect(Saas::AiAgents::Context).not_to receive(:latest_incoming)
    expect(Saas::AiAgents::Respond).not_to receive(:new)
    described_class.perform_now(account.id, conversation.id, message.id)
  end

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

  it 'keeps attachment-only messages from being debounced as stale' do
    account = create(:account)
    inbox = create(:inbox, account: account)
    conversation = create(:conversation, account: account, inbox: inbox)
    message = create(:message, account: account, inbox: inbox, conversation: conversation, content: nil)
    message.attachments.create!(account: account, file_type: :image,
                                file: fixture_file_upload('spec/assets/avatar.png', 'image/png'))
    agent = instance_double(Saas::AiAgent, attachment_interpretation_enabled?: true, group_response_blacklist: [])
    responder = instance_double(Saas::AiAgents::Respond, perform: nil)

    allow(Saas::AiAgents::Runtime).to receive(:agent_for).with(conversation).and_return(agent)
    allow(Saas::AiAgents::Runtime).to receive(:enabled?).with(conversation).and_return(true)
    allow(Saas::AiAgents::Respond).to receive(:new).and_return(responder)
    allow(Saas::AiAgents::Context).to receive(:latest_incoming).and_call_original

    described_class.perform_now(account.id, conversation.id, message.id)

    expect(Saas::AiAgents::Context).to have_received(:latest_incoming).with(conversation, include_attachments: true)
    expect(Saas::AiAgents::Respond).to have_received(:new).with(conversation, message)
  end
end
