require 'rails_helper'

RSpec.describe AiAgentListener do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { account.saas_ai_agents.build }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
  let(:event) { Events::Base.new('message.created', Time.current, message: message) }

  before { allow(Saas::AiAgents::RespondJob).to receive(:perform_later) }

  context 'with a group response blacklist' do
    before do
      conversation.contact_inbox.update!(source_id: '120363123456789@g.us')
      agent.configure!({ name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true,
                         respond_to_groups: true, response_delay_seconds: 0, audio_enabled: true,
                         group_response_blacklist: ['5562999991111'] }, selected_inboxes: [inbox])
    end

    it 'persists blocked text in the conversation history without scheduling a response' do
      expect(Saas::AiAgents::RespondJob).not_to receive(:perform_later)
      blocked = create(:message, account: account, inbox: inbox, conversation: conversation,
                                 content_attributes: { participant: '5562999991111@s.whatsapp.net' })
      described_class.instance.message_created(Events::Base.new('message.created', Time.current, message: blocked))
      expect(conversation.messages).to include(blocked)
      expect(Saas::AiAgents::Context.build(conversation, agent, blocked).last[:content]).to include(blocked.content)
    end

    it 'does not enqueue a response for a blocked LID with a real participantAlt phone' do
      blocked = create(:message, account: account, inbox: inbox, conversation: conversation,
                                 content_attributes: { whatsapp_message_key: {
                                   remoteJid: '120363123456789@g.us', participant: '247613823709228@lid',
                                   participantAlt: '5562999991111@s.whatsapp.net'
                                 } })
      described_class.instance.message_created(Events::Base.new('message.created', Time.current, message: blocked))
      expect(Saas::AiAgents::RespondJob).not_to have_received(:perform_later)
      expect(blocked.reload).to be_persisted
    end

    [
      [:audio, 'sample.mp3', 'audio/mpeg'],
      [:image, 'avatar.png', 'image/png'],
      [:file, 'attachment.pdf', 'application/pdf'],
      [:video, 'sample.mp4', 'video/mp4']
    ].each do |type, filename, content_type|
      it "keeps blocked #{type} attachments without scheduling AI or consuming credits" do
        expect(Saas::AiAgents::RespondJob).not_to receive(:perform_later)
        expect(Saas::Audio::TranscriptionService).not_to receive(:new)
        blocked = create(:message, account: account, inbox: inbox, conversation: conversation, content: nil,
                                   content_attributes: { participant: '5562999991111@s.whatsapp.net' })
        attachment = blocked.attachments.create!(account: account, file_type: type,
                                                 file: fixture_file_upload("spec/assets/#{filename}", content_type))
        expect do
          described_class.instance.message_created(Events::Base.new('message.created', Time.current, message: blocked))
        end.not_to change(Saas::UsageRecord, :count)
        expect(blocked.reload.attachments).to include(attachment)
        expect(conversation.messages).to include(blocked)
      end
    end

    it 'schedules a response for another participant' do
      other = create(:message, account: account, inbox: inbox, conversation: conversation,
                               content_attributes: { participant: '5562988882222@s.whatsapp.net' })
      expect(Saas::AiAgents::RespondJob).to have_received(:perform_later).with(account.id, conversation.id, other.id)
    end

    it 'allows the same blocked number in a private conversation' do
      conversation.contact_inbox.update!(source_id: '5562999991111@s.whatsapp.net')
      private_message = create(:message, account: account, inbox: inbox, conversation: conversation,
                                         content_attributes: { participant: '5562999991111@s.whatsapp.net' })
      expect(Saas::AiAgents::RespondJob).to have_received(:perform_later).with(account.id, conversation.id, private_message.id)
    end

    it 'preserves group replies being disabled and retains the saved blacklist' do
      agent.update!(respond_to_groups: false)
      described_class.instance.message_created(event)
      expect(Saas::AiAgents::RespondJob).not_to have_received(:perform_later)
      expect(agent.reload.group_response_blacklist).to eq(['5562999991111'])
    end
  end

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

  it 'handles the first message of a conversation whose display_id is still marked as changed' do
    agent.configure!({ name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true },
                     selected_inboxes: [inbox])
    message.conversation.display_id_will_change!
    expect { message.conversation.with_lock {} }.to raise_error(RuntimeError, /unpersisted changes/)

    expect { described_class.instance.message_created(event) }.not_to raise_error
    expect(Saas::AiAgents::RespondJob).to have_received(:perform_later).with(account.id, conversation.id, message.id)
  end

  it 'does not raise when the AI runtime fails, so the customer message is not rejected' do
    allow(Saas::AiAgents::Runtime).to receive(:enabled?).and_raise(StandardError, 'boom')
    allow(ChatwootExceptionTracker).to receive(:new).and_call_original

    expect { described_class.instance.message_created(event) }.not_to raise_error
    expect(ChatwootExceptionTracker).to have_received(:new).with(an_instance_of(StandardError), account: account)
    expect(Saas::AiAgents::RespondJob).not_to have_received(:perform_later)
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
