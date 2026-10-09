require 'rails_helper'

RSpec.describe Saas::AiAgents::Context do
  let(:conversation) { create(:conversation) }
  let(:agent) { instance_double(Saas::AiAgent, system_prompt: 'Full prompt ' * 1000) }

  it 'excludes private notes and maps bounded public history chronologically' do
    create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: 'Question')
    Messages::MessageBuilder.new(nil, conversation, { content: 'Previous reply', message_type: 'outgoing' }).perform
    create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation,
                     content: 'Private secret', private: true, message_type: :outgoing)
    incoming = create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: 'A' * 5000)
    history = described_class.build(conversation, agent, incoming)
    expect(history.first).to eq(role: 'system', content: agent.system_prompt)
    expect(history.drop(1).map { |entry| entry[:role] }).to eq(%w[user assistant user])
    expect(history.last[:content].length).to eq(4000)
    expect(history.to_s).not_to include('Private secret')
  end

  it 'ignores whitespace-only input and generated AI input when finding the latest customer message' do
    valid = create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: 'Question')
    create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: " \n\t")
    create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation,
                     content: 'Echo', content_attributes: { generated_by_ai: true })
    expect(described_class.latest_incoming(conversation)).to eq(valid)
  end
end
