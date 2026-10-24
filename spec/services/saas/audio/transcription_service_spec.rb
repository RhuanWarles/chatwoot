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
    Saas::Wallet.for_account(account, 'audio_minutes').credit!(units: 2, reference: 'audio-spec-credit')
    allow(Saas::Audio::Providers::OpenAi).to receive(:new).and_return(provider)
  end

  it 'transcribes audio, persists metadata and settles audio credits' do
    allow(provider).to receive(:transcribe).and_return('Texto do áudio')

    result = with_modified_env SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' do
      described_class.new(attachment: attachment, account: account, agent: agent).perform
    end

    expect(result).to include(success: true, text: 'Texto do áudio', reused: false)
    expect(attachment.reload.meta).to include('transcribed_text' => 'Texto do áudio', 'transcription_model' => 'whisper-1')
    expect(Saas::Wallet.for_account(account, 'audio_minutes').reload.available_units).to eq(1)
    expect(Saas::UsageRecord.where(source: 'audio_transcription')).to exist
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
end
