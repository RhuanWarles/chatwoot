require 'rails_helper'

RSpec.describe Saas::AccountAiAccess do
  let(:account) { create(:account) }

  it 'preserves enabled access by default for new accounts' do
    expect(account.feature_enabled?(:text_ai)).to be(true)
    expect(account.feature_enabled?(:voice_ai)).to be(true)
  end

  it 'blocks direct text requests before creating a wallet, generation or provider request' do
    account.disable_features!(:text_ai)
    service = Saas::TextService.new(account)
    expect do
      service.create!(prompt: 'Hello', request_id: SecureRandom.uuid)
    end.to raise_error(CustomExceptions::SaasError, 'text_ai_disabled')
    expect(account.saas_wallets).to be_empty
    expect(account.saas_text_generations).to be_empty
    expect { service.generate(nil) }.to raise_error(CustomExceptions::SaasError, 'text_ai_disabled')
  end

  %w[inbound outbound].each do |direction|
    it "blocks #{direction} voice admission before reserving funds or creating calls" do
      account.disable_features!(:voice_ai)
      expect do
        Saas::VoiceService.new(account).reserve!(direction: direction, request_id: SecureRandom.uuid, customer_number: '+5562999999999')
      end.to raise_error(CustomExceptions::SaasError, 'voice_ai_disabled')
      expect(account.saas_wallets).to be_empty
      expect(account.saas_voice_calls).to be_empty
    end
  end

  it 'releases an already queued voice reservation when access is disabled before submission' do
    wallet = Saas::Wallet.for_account(account, 'voice_seconds')
    wallet.credit!(units: 600, reference: 'initial')
    usage = wallet.reserve!(units: 60, reference: 'pending')
    call = account.saas_voice_calls.create!(usage_record: usage, request_id: SecureRandom.uuid, direction: 'outbound',
                                            customer_number: '+5562999999999', assistant_id: 'assistant', phone_number_id: 'phone',
                                            max_duration_seconds: 60)
    account.disable_features!(:voice_ai)
    expect(Saas::VapiClient).not_to receive(:new)
    Saas::StartVoiceCallJob.perform_now(call.id)
    expect(call.reload.status).to eq('failed')
    expect(call.ended_reason).to eq('voice_ai_disabled')
    expect(usage.reload.status).to eq('released')
    expect(wallet.reload.available_units).to eq(600)
  end

  it 'releases queued text credits without calling the provider after text access is disabled' do
    wallet = Saas::Wallet.for_account(account, 'text_credits')
    wallet.credit!(units: 100, reference: 'initial')
    usage = wallet.reserve!(units: 1, reference: 'pending')
    generation = account.saas_text_generations.create!(prompt: 'Hello', request_id: SecureRandom.uuid, mode: 'platform', provider: 'openai',
                                                       model: 'test', usage_record: usage)
    account.disable_features!(:text_ai)
    expect(RubyLLM).not_to receive(:context)
    Saas::GenerateTextJob.perform_now(generation.id)
    expect(generation.reload.status).to eq('failed')
    expect(usage.reload.status).to eq('released')
    expect(wallet.reload.available_units).to eq(100)
  end
end
