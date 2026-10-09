require 'rails_helper'

RSpec.describe AiAgentListener do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { account.saas_ai_agents.build }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
  let(:event) { Events::Base.new('message.created', Time.current, message: message) }

  before { allow(Saas::AiAgents::RespondJob).to receive(:perform_later) }

  it 'enqueues only an active linked agent' do
    described_class.instance.message_created(event)
    expect(Saas::AiAgents::RespondJob).not_to have_received(:perform_later)
    agent.configure!({ name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true },
                     selected_inboxes: [inbox])
    described_class.instance.message_created(event)
    expect(Saas::AiAgents::RespondJob).to have_received(:perform_later).with(account.id, conversation.id, message.id)
    agent.update!(active: false)
    described_class.instance.message_created(event)
    expect(Saas::AiAgents::RespondJob).to have_received(:perform_later).once
  end

  it 'does not use an agent from another account or inbox' do
    other = create(:account)
    other.saas_ai_agents.build.configure!({ name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true },
                                         selected_inboxes: [create(:inbox, account: other)])
    described_class.instance.message_created(event)
    expect(Saas::AiAgents::RespondJob).not_to have_received(:perform_later)
  end

  it 'only responds in groups when the agent explicitly enables them' do
    agent.configure!({ name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true },
                     selected_inboxes: [inbox])
    conversation.contact_inbox.update!(source_id: '120363000000000@g.us')
    described_class.instance.message_created(event)
    expect(Saas::AiAgents::RespondJob).not_to have_received(:perform_later)
    agent.configure!({ respond_to_groups: true })
    described_class.instance.message_created(event)
    expect(Saas::AiAgents::RespondJob).to have_received(:perform_later).with(account.id, conversation.id, message.id)
  end

  it 'does not compete with an existing native inbox bot' do
    agent.configure!({ name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true },
                     selected_inboxes: [inbox])
    allow(conversation.inbox).to receive(:active_bot?).and_return(true)
    described_class.instance.message_created(event)
    expect(Saas::AiAgents::RespondJob).not_to have_received(:perform_later)
  end

  it 'ignores outgoing and paused conversations even with an active linked agent' do
    agent.configure!({ name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true },
                     selected_inboxes: [inbox])
    outgoing = Messages::MessageBuilder.new(nil, conversation, { content: 'AI', message_type: 'outgoing' }).perform
    described_class.instance.message_created(Events::Base.new('message.created', Time.current, message: outgoing))
    conversation.update!(additional_attributes: { 'ai_agent_state' => 'paused' })
    described_class.instance.message_created(event)
    expect(Saas::AiAgents::RespondJob).not_to have_received(:perform_later)
  end
end
