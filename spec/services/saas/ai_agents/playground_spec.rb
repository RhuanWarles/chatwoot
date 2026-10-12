require 'rails_helper'

RSpec.describe Saas::AiAgents::Playground do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:agent) do
    account.saas_ai_agents.create!(name: 'Larissa', system_prompt: 'Help', provider: 'openai', model: 'gpt-4.1', active: false)
  end
  let(:provider) { instance_double(Saas::AiAgents::Providers::Platform) }
  let(:session_id) { SecureRandom.uuid }
  let(:request_id) { SecureRandom.uuid }

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    account.create_saas_ai_setting!(text_mode: 'platform')
    allow(Saas::TextService).to receive(:configured?).and_return(true)
    allow(Saas::TextService).to receive(:platform_config).and_return(provider: 'openai', model: 'gpt-4.1')
    allow(Saas::AiAgents::Provider).to receive(:for).with(account, 'openai', mode: 'platform').and_return(provider)
    allow(provider).to receive(:generate).and_return(content: 'Olá', usage: {
      'prompt_tokens' => 10, 'completion_tokens' => 5, 'total_tokens' => 15
    })
    Rails.cache.clear
  end

  it 'does not consume platform credits and records playground usage' do
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 20, reference: 'playground-spec-credit')

    result = described_class.new(account, user, agent).message(session_id: session_id, request_id: request_id, prompt: 'Hello')

    expect(result[:message]['content']).to eq('Olá')
    expect(wallet.reload.available_units).to eq(20)
    expect(Saas::UsageRecord.where(account: account, source: 'playground')).to contain_exactly(
      have_attributes(status: 'completed', units: 0, prompt_tokens: 10, completion_tokens: 5, total_tokens: 15)
    )
  end

  it 'uses linked knowledge and returns sources without debiting credits' do
    base = account.saas_knowledge_bases.create!(name: 'FAQ')
    agent.configure!({}, selected_knowledge_bases: [base])
    sources = [{ base: 'FAQ', document: 'Warranty', content: 'Warranty is 12 months.', score: 0.9 }]
    allow(Saas::Knowledge::Retrieval).to receive(:for_agent).with(agent, 'Warranty?').and_return(sources)
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 20, reference: 'knowledge-test-credit')

    result = described_class.new(account, user, agent).message(session_id: session_id, request_id: request_id, prompt: 'Warranty?')

    expect(result[:message]['knowledge_sources']).to eq(sources)
    expect(provider).to have_received(:generate).with(hash_including(messages: include(hash_including(content: include('12 months')))))
    expect(wallet.reload.available_units).to eq(20)
  end

  it 'keeps the same request idempotent without a second provider call' do
    service = described_class.new(account, user, agent)
    service.message(session_id: session_id, request_id: request_id, prompt: 'Hello')
    service.message(session_id: session_id, request_id: request_id, prompt: 'Hello')

    expect(provider).to have_received(:generate).once
    expect(Saas::UsageRecord.where(account: account, source: 'playground').count).to eq(1)
  end

  it 'records provider failures without touching the wallet' do
    allow(provider).to receive(:generate).and_raise(CustomExceptions::AiAgentError, 'provider_error')
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 20, reference: 'playground-spec-credit')

    expect do
      described_class.new(account, user, agent).message(session_id: session_id, request_id: request_id, prompt: 'Hello')
    end.to raise_error(CustomExceptions::AiAgentError)

    expect(wallet.reload.available_units).to eq(20)
    expect(Saas::UsageRecord.where(account: account, source: 'playground').last.status).to eq('failed')
  end
end
