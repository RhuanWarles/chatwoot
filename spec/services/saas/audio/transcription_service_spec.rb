require 'rails_helper'

RSpec.describe Saas::Audio::TranscriptionService, type: :service do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, account: account, conversation: conversation, content: nil) }
  let(:attachment) do
    message.attachments.create!(account: account, file_type: :audio,
                                file: fixture_file_upload('public/audio/widget/ding.mp3'))
  end
  let(:agent) { account.saas_ai_agents.create!(name: 'Audio', system_prompt: 'Help', provider: 'openai', model: 'test') }
  let(:provider) { instance_double(Saas::Audio::Providers::OpenAi) }

  before do
    allow(Saas::Audio::Providers::OpenAi).to receive(:new).and_return(provider)
  end

  it 'transcribes audio, persists metadata and settles proportional text credits' do
    Saas::Wallet.for_account(account, 'text_credits').credit!(units: 5, reference: 'audio-spec-credit')
    attachment.update!(meta: { 'duration' => 30 })
    allow(provider).to receive(:transcribe).and_return('Texto do áudio')

    result = with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' do
      described_class.new(attachment: attachment, account: account, agent: agent).perform
    end

    expect(result).to include(success: true, text: 'Texto do áudio', reused: false)
    expect(attachment.reload.meta).to include('transcribed_text' => 'Texto do áudio', 'transcription_model' => 'whisper-1')
    expect(Saas::Wallet.for_account(account, 'text_credits').reload.available_units).to eq(0)
    expect(Saas::Wallet.find_by(account: account, resource: 'audio_minutes')).to be_nil
    expect(Saas::UsageRecord.where(source: 'audio_transcription').first.metadata).to include(
      'audio_minutes' => 0.5, 'audio_credits_used' => 5
    )
  end

  it 'charges one credit per minute proportionally and rounds partial credits up' do
    Saas::Wallet.for_account(account, 'text_credits').credit!(units: 10, reference: 'audio-spec-credit')
    attachment.update!(meta: { 'duration' => 60 })
    allow(provider).to receive(:transcribe).and_return('Texto do áudio')

    with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' do
      described_class.new(attachment: attachment, account: account, agent: agent).perform
    end

    expect(Saas::Wallet.for_account(account, 'text_credits').reload.available_units).to eq(0)
    expect(Saas::UsageRecord.where(source: 'audio_transcription').first.units).to eq(10)
  end

  it 'charges the exact proportional cost for two minutes' do
    Saas::Wallet.for_account(account, 'text_credits').credit!(units: 20, reference: 'audio-spec-credit')
    attachment.update!(meta: { 'duration' => 120 })
    allow(provider).to receive(:transcribe).and_return('Texto do áudio')

    with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' do
      described_class.new(attachment: attachment, account: account, agent: agent).perform
    end

    expect(Saas::Wallet.for_account(account, 'text_credits').reload.available_units).to eq(0)
    expect(Saas::UsageRecord.where(source: 'audio_transcription').first.units).to eq(20)
  end

  it 'rejects transcription when the main text credit balance is insufficient' do
    Saas::Wallet.for_account(account, 'text_credits').credit!(units: 4, reference: 'audio-spec-credit')
    attachment.update!(meta: { 'duration' => 30 })

    result = with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' do
      described_class.new(attachment: attachment, account: account, agent: agent).perform
    end

    expect(result).to eq(success: false, error: 'insufficient_balance')
    expect(provider).not_to have_received(:transcribe)
  end

  it 'does not charge the audio wallet when it exists with no balance' do
    Saas::Wallet.for_account(account, 'text_credits').credit!(units: 5, reference: 'audio-spec-credit')
    audio_wallet = Saas::Wallet.for_account(account, 'audio_minutes')
    attachment.update!(meta: { 'duration' => 30 })
    allow(provider).to receive(:transcribe).and_return('Texto do áudio')

    with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' do
      described_class.new(attachment: attachment, account: account, agent: agent).perform
    end

    expect(audio_wallet.reload.balance_units).to eq(0)
    expect(Saas::Wallet.for_account(account, 'text_credits').reload.available_units).to eq(0)
  end

  it 'does not charge twice when the same attachment is processed again' do
    Saas::Wallet.for_account(account, 'text_credits').credit!(units: 5, reference: 'audio-spec-credit')
    attachment.update!(meta: { 'duration' => 30 })
    allow(provider).to receive(:transcribe).and_return('Texto do áudio')

    with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' do
      service = described_class.new(attachment: attachment, account: account, agent: agent)
      expect(service.perform).to include(success: true, reused: false)
      expect(service.perform).to include(success: true, reused: true)
    end

    expect(provider).to have_received(:transcribe).once
    expect(Saas::Wallet.for_account(account, 'text_credits').reload.available_units).to eq(0)
    expect(Saas::UsageRecord.where(source: 'audio_transcription').count).to eq(1)
  end

  it 'does not call the provider when a transcription already exists' do
    attachment.update!(meta: { 'transcribed_text' => 'Já transcrito' })

    result = described_class.new(attachment: attachment, account: account, agent: agent).perform

    expect(result).to include(success: true, text: 'Já transcrito', reused: true)
    expect(provider).not_to have_received(:transcribe)
  end

  it 'returns a configuration error without exposing the API key' do
    result = with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: '', SAAS_AUDIO_API_KEY: 'secret-key' do
      described_class.new(attachment: attachment, account: account, agent: agent).perform
    end

    expect(result).to eq(success: false, error: 'audio_not_configured')
  end

  context 'without an AI agent' do
    before do
      Saas::Wallet.for_account(account, 'text_credits').credit!(units: 5, reference: 'audio-spec-credit')
      attachment.update!(meta: { 'duration' => 30 })
      allow(provider).to receive(:transcribe).and_return('Texto do áudio')
    end

    def transcribe(**)
      with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' do
        described_class.new(attachment: attachment, account: account, **).perform
      end
    end

    it 'transcribes and charges the text credits of the account' do
      expect(transcribe).to include(success: true, text: 'Texto do áudio', reused: false)

      expect(attachment.reload.meta).to include('transcribed_text' => 'Texto do áudio')
      expect(Saas::Wallet.for_account(account, 'text_credits').reload.available_units).to eq(0)
      expect(Saas::UsageRecord.where(source: 'audio_transcription').first.reference).to eq("ai_audio:#{account.id}:#{attachment.id}:account")
    end

    it 'tells the conversation that the message changed so the text appears without a refresh' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      transcribe

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(Events::Types::MESSAGE_UPDATED, anything, hash_including(message: message))
    end

    it 'still keeps the transcription when the broadcast fails' do
      allow_any_instance_of(Message).to receive(:send_update_event).and_raise(StandardError, 'cable down')

      expect(transcribe).to include(success: true)
      expect(attachment.reload.meta).to include('transcribed_text' => 'Texto do áudio')
    end
  end

  describe '.available_for?' do
    it 'needs the platform configuration and the text AI feature' do
      with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' do
        expect(described_class.available_for?(account)).to be(true)

        account.disable_features!('text_ai')
        expect(described_class.available_for?(account)).to be(false)
      end
    end

    it 'is false when the platform has no transcription key' do
      with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: '' do
        expect(described_class.available_for?(account)).to be(false)
      end
    end
  end

  describe '#blocking_error' do
    subject(:error) do
      with_modified_env(SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key') do
        described_class.new(attachment: attachment, account: account).blocking_error
      end
    end

    it 'is nil when there are credits to transcribe' do
      Saas::Wallet.for_account(account, 'text_credits').credit!(units: 5, reference: 'audio-spec-credit')

      expect(error).to be_nil
    end

    it 'asks for credits when the balance is empty' do
      expect(error).to eq('insufficient_balance')
    end

    it 'is refused when the account has no text AI' do
      account.disable_features!('text_ai')

      expect(error).to eq('text_ai_disabled')
    end
  end
end
