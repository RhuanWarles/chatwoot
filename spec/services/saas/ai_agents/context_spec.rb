require 'rails_helper'

RSpec.describe Saas::AiAgents::Context do
  let(:conversation) { create(:conversation) }
  let(:agent) { instance_double(Saas::AiAgent, system_prompt: 'Full prompt ' * 1000, context_messages_limit: 20) }

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

  it 'keeps memory, knowledge and the latest customer message in the existing priority order' do
    incoming = create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: 'Warranty?')
    knowledge = Saas::Knowledge::Retrieval.messages([{ content: 'Warranty is 12 months.' }])
    messages = described_class.build(conversation, agent, incoming, memory_context: 'Customer name: Rhuan', knowledge_context: knowledge)
    expect(messages[0]).to eq(role: 'system', content: agent.system_prompt)
    expect(messages[1]).to eq(role: 'system', content: 'Customer name: Rhuan')
    expect(messages[2..3]).to eq(knowledge)
    expect(messages.last[:role]).to eq('user')
    expect(messages.last[:content]).to end_with("\nWarranty?")
  end

  it 'ignores whitespace-only input and generated AI input when finding the latest customer message' do
    valid = create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: 'Question')
    create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: " \n\t")
    create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation,
                     content: 'Echo', content_attributes: { generated_by_ai: true })
    expect(described_class.latest_incoming(conversation)).to eq(valid)
  end

  it 'uses the agent context limit while keeping the newest messages chronological' do
    agent = instance_double(Saas::AiAgent, system_prompt: 'Prompt', context_messages_limit: 2)
    create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: 'First')
    create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: 'Second')
    incoming = create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation, content: 'Third')

    history = described_class.build(conversation, agent, incoming)

    expect(history.drop(1).map { |entry| entry[:role] }).to eq(%w[user user user])
    expect(history.drop(1).map { |entry| entry[:content].split("\n").last }).to eq(%w[First Second Third])
    expect(history.drop(1).count { |entry| entry[:content].end_with?(incoming.content) }).to eq(1)
  end

  it 'keeps the name and identifier of different group participants in chronological order' do
    first = create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation,
                   content: 'First',
                   content_attributes: { participant_name: 'Alice', participant_identifier: 'alice@lid' })
    second = create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation,
                    content: 'Second',
                    content_attributes: { participant_name: 'Bruno', participant_identifier: 'bruno@s.whatsapp.net' })

    history = described_class.build(conversation, agent, second)
    contents = history.drop(1).map { |entry| entry[:content] }

    expect(contents).to eq(
      ["[Participante: Alice; identificador: alice@lid]\nFirst",
       "[Participante: Bruno; identificador: bruno@s.whatsapp.net]\nSecond"]
    )
    expect(first.id).to be < second.id
  end

  it 'keeps the author metadata in an audio transcription' do
    audio_message = create(:message, account: conversation.account, inbox: conversation.inbox, conversation: conversation,
                           content: nil,
                           content_attributes: { participant_name: 'Carla', participant_identifier: 'carla@lid' })
    audio_message.attachments.create!(account: conversation.account, file_type: :audio,
                                      meta: { 'transcribed_text' => 'Áudio transcrito' })

    history = described_class.build(conversation, agent, audio_message)

    expect(history.last[:content]).to eq("[Participante: Carla; identificador: carla@lid]\n[Voice Message] Áudio transcrito")
  end

  it 'removes internal author context from model output' do
    content = "[Participante: Larissa; identificador: Saas::AiAgent:3]\nTenho sim!"

    expect(described_class.strip_internal_author_context(content)).to eq('Tenho sim!')
  end
end
