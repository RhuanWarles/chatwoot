require 'rails_helper'

RSpec.describe Saas::AiAgents::Respond do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { account.saas_ai_agents.build }
  let(:incoming) { create(:message, account: account, inbox: inbox, conversation: conversation) }
  let(:provider) { instance_double(Saas::AiAgents::Providers::OpenAi) }

  before do
    account.create_saas_ai_setting!(text_mode: 'byok', text_provider: 'openai', text_model: 'test-model', text_api_key: 'test-key')
    agent.configure!({ name: 'Assistente', system_prompt: 'Ajude o cliente', provider: 'openai', model: 'test-model', active: true },
                     selected_inboxes: [inbox])
    allow(Saas::AiAgents::Provider).to receive(:for).with(account, 'openai', mode: 'byok').and_return(provider)
    allow(provider).to receive(:generate).and_return(content: 'Olá!', usage: {})
  end

  it 'creates one native public reply and skips duplicate processing' do
    2.times { described_class.new(conversation, incoming).perform }
    reply = conversation.messages.outgoing.last
    expect(reply.content).to eq('Olá!')
    expect(reply.private?).to be(false)
    expect(reply.sender).to eq(agent)
    expect(conversation.reload.waiting_since).to be_nil
    expect(reply.push_event_data[:sender]).to include(name: 'Assistente', type: 'agent_bot')
    expect(reply.content_attributes).to include('generated_by_ai' => true, 'ai_agent_id' => agent.id)
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(provider).to have_received(:generate).once
    expect(conversation.reload.additional_attributes['ai_agent_state']).to eq('active')
  end

  it 'preserves an active agent but blocks the provider and credit reservation while text access is disabled' do
    account.saas_ai_setting.update!(text_mode: 'platform')
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 400, reference: 'initial')
    incoming
    account.disable_features!(:text_ai)
    expect { described_class.new(conversation, incoming).perform }.not_to change(Saas::UsageRecord, :count)
    expect(Saas::AiAgents::Provider).not_to have_received(:for)
    expect(agent.reload.active).to be(true)
    expect(wallet.reload.available_units).to eq(400)
    expect(conversation.messages.outgoing).to be_empty
    account.saas_ai_setting.update!(text_mode: 'byok')
    account.enable_features!(:text_ai)
    described_class.new(conversation, incoming).perform
    expect(provider).to have_received(:generate).once
    expect(conversation.messages.outgoing.count).to eq(1)
  end

  it 'pauses on a human public response and never responds while paused' do
    incoming
    user = create(:user, account: account)
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: user, message_type: :outgoing)
    described_class.new(conversation, incoming).perform
    expect(conversation.reload.additional_attributes).to include('ai_agent_state' => 'human', 'ai_agent_paused_by_id' => user.id)
    expect(provider).not_to have_received(:generate)
  end

  it 'does not pause for outgoing AI metadata or private human notes' do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                     content_attributes: { generated_by_ai: true, ai_agent_id: agent.id })
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, private: true)
    expect(conversation.reload.additional_attributes['ai_agent_state']).to be_nil
    described_class.new(conversation, incoming).perform
    expect(provider).to have_received(:generate).once
  end

  it 'discards the generated reply when a human takes over during generation' do
    allow(provider).to receive(:generate) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: create(:user, account: account), message_type: :outgoing)
      { content: 'Obsolete', usage: {} }
    end
    described_class.new(conversation, incoming).perform
    expect(conversation.messages.outgoing.pluck(:content)).not_to include('Obsolete')
  end

  it 'coalesces pending input into the latest incoming message' do
    first = incoming
    latest = create(:message, account: account, inbox: inbox, conversation: conversation, content: 'Mais uma pergunta')
    described_class.new(conversation, first).perform
    described_class.new(conversation, latest).perform
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(conversation.messages.outgoing.last.content_attributes['ai_agent_incoming_message_id']).to eq(latest.id)
  end

  it 'does not create a reply on provider failure and releases the lock for another attempt' do
    allow(provider).to receive(:generate).and_raise(CustomExceptions::AiAgentError::Transient, 'provider_http_429')
    expect { described_class.new(conversation, incoming).perform }.to raise_error(CustomExceptions::AiAgentError::Transient)
    expect(conversation.messages.outgoing.count).to eq(0)
    allow(provider).to receive(:generate).and_return(content: 'Recovered', usage: {})
    described_class.new(conversation, incoming).perform
    expect(conversation.messages.outgoing.count).to eq(1)
  end

  it 'reserves and settles one platform credit for an automatic reply' do
    account.saas_ai_setting.update!(text_mode: 'platform')
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 2, reference: 'spec-platform-credit')
    platform_provider = instance_double(Saas::AiAgents::Providers::Platform)
    allow(Saas::AiAgents::Provider).to receive(:for).with(account, 'openai', mode: 'platform').and_return(platform_provider)
    allow(platform_provider).to receive(:generate).and_return(content: 'Resposta da plataforma', usage: { 'total_tokens' => 7 })
    with_modified_env SAAS_TEXT_PROVIDER: 'openai', SAAS_TEXT_MODEL: 'platform-model', SAAS_TEXT_API_KEY: 'platform-key' do
      described_class.new(conversation, incoming).perform
      described_class.new(conversation, incoming).perform
    end

    expect(wallet.reload.available_units).to eq(1)
    record = wallet.usage_records.find_by(reference: "ai_agent:#{account.id}:#{conversation.id}:#{incoming.id}:#{agent.id}")
    expect(record).to have_attributes(kind: 'consumption', status: 'settled', units: 1)
    expect(record.metadata).to include('mode' => 'platform', 'ai_agent_id' => agent.id)
    expect(platform_provider).to have_received(:generate).once
  end

  it 'does not call the provider or consume credits when the platform balance is insufficient' do
    account.saas_ai_setting.update!(text_mode: 'platform')
    platform_provider = instance_double(Saas::AiAgents::Providers::Platform)
    allow(platform_provider).to receive(:generate)
    allow(Saas::AiAgents::Provider).to receive(:for).with(account, 'openai', mode: 'platform').and_return(platform_provider)
    with_modified_env SAAS_TEXT_PROVIDER: 'openai', SAAS_TEXT_MODEL: 'platform-model', SAAS_TEXT_API_KEY: 'platform-key' do
      described_class.new(conversation, incoming).perform
    end

    expect(platform_provider).not_to have_received(:generate)
    expect(Saas::Wallet.for_account(account, 'text_credits').available_units).to eq(0)
    expect(conversation.messages.outgoing.count).to eq(0)
  end

  it 'releases stale platform output and skips a retry after human takeover' do
    account.saas_ai_setting.update!(text_mode: 'platform')
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 1, reference: 'stale-platform-credit')
    platform_provider = instance_double(Saas::AiAgents::Providers::Platform)
    allow(Saas::AiAgents::Provider).to receive(:for).with(account, 'openai', mode: 'platform').and_return(platform_provider)
    allow(platform_provider).to receive(:generate) do
      expect(wallet.reload.available_units).to eq(0)
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: create(:user, account: account), message_type: :outgoing, content: 'Human reply')
      { content: 'Stale AI reply', usage: {} }
    end
    allow(Rails.logger).to receive(:info).and_call_original

    with_modified_env SAAS_TEXT_PROVIDER: 'openai', SAAS_TEXT_MODEL: 'platform-model', SAAS_TEXT_API_KEY: 'platform-key' do
      2.times { described_class.new(conversation, incoming).perform }
    end

    expect(conversation.messages.outgoing.pluck(:content)).to eq(['Human reply'])
    expect(wallet.reload.available_units).to eq(1)
    expect(wallet.balance_units).to eq(1)
    expect(wallet.usage_records.where(kind: 'consumption').count).to eq(1)
    expect(wallet.usage_records.find_by(kind: 'consumption')).to have_attributes(status: 'released', units: 0)
    expect(platform_provider).to have_received(:generate).once
    expect(Rails.logger).to have_received(:info).with(include('discarded_stale_response'))
  end

  it 'releases a platform reservation when provider generation fails' do
    account.saas_ai_setting.update!(text_mode: 'platform')
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 1, reference: 'spec-platform-failure')
    platform_provider = instance_double(Saas::AiAgents::Providers::Platform)
    allow(Saas::AiAgents::Provider).to receive(:for).with(account, 'openai', mode: 'platform').and_return(platform_provider)
    allow(platform_provider).to receive(:generate).and_raise(CustomExceptions::AiAgentError::Transient, 'provider_timeout_or_connection_error')
    expect do
      with_modified_env SAAS_TEXT_PROVIDER: 'openai', SAAS_TEXT_MODEL: 'platform-model', SAAS_TEXT_API_KEY: 'platform-key' do
        described_class.new(conversation, incoming).perform
      end
    end.to raise_error(CustomExceptions::AiAgentError::Transient)

    record = wallet.usage_records.find_by(reference: "ai_agent:#{account.id}:#{conversation.id}:#{incoming.id}:#{agent.id}")
    expect(record).to have_attributes(status: 'released', units: 0, reserved_units: 1)
    expect(wallet.reload.available_units).to eq(1)
  end

  it 'skips inactive agents and outgoing triggers' do
    agent.update!(active: false)
    described_class.new(conversation, incoming).perform
    expect(provider).not_to have_received(:generate)
    agent.update!(active: true)
    outgoing = Messages::MessageBuilder.new(nil, conversation, { content: 'AI', message_type: 'outgoing' }).perform
    described_class.new(conversation, outgoing).perform
    expect(provider).not_to have_received(:generate)
  end

  it 'refuses concurrent generation while another database session owns the conversation lock' do
    message = incoming
    key = described_class::LOCK_NAMESPACE + conversation.id
    config = Conversation.connection_db_config.configuration_hash
    holder = PG.connect(host: config[:host], port: config[:port], dbname: config[:database],
                        user: config[:username], password: config[:password])
    holder.exec("SELECT pg_advisory_lock(#{key})")
    expect { described_class.new(conversation, message).perform }.to raise_error(CustomExceptions::AiAgentError::Busy)
    expect(provider).not_to have_received(:generate)
  ensure
    holder&.exec("SELECT pg_advisory_unlock(#{key})")
    holder&.close
  end

  it 'discards stale output when another incoming arrives during generation' do
    allow(provider).to receive(:generate) do
      create(:message, account: account, inbox: inbox, conversation: conversation, content: 'New question')
      { content: 'Stale reply', usage: {} }
    end
    described_class.new(conversation, incoming).perform
    expect(conversation.messages.outgoing.count).to eq(0)
  end
end
