require 'rails_helper'

RSpec.describe Attachment do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:received) { create(:message, account: account, inbox: inbox, conversation: conversation) }

  def attach_audio(to_message)
    to_message.attachments.create!(account: account, file_type: :audio,
                                   file: fixture_file_upload('spec/assets/sample.mp3', 'audio/mpeg'))
  end

  context 'when the account transcribes audios with its text credits' do
    before do
      account.update!(audio_transcriptions: true)
      allow(Saas::Audio::TranscriptionService).to receive(:available_for?).with(account).and_return(true)
    end

    it 'queues the credits based transcription of a received audio instead of the Captain one' do
      expect(Messages::AudioTranscriptionJob).not_to receive(:perform_later)

      expect { attach_audio(received) }.to have_enqueued_job(Saas::TranscribeAudioJob)
    end

    it 'keeps the previous flow for an audio sent by an agent' do
      sent = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                              sender: create(:user, account: account))
      expect(Messages::AudioTranscriptionJob).to receive(:perform_later)

      expect { attach_audio(sent) }.not_to have_enqueued_job(Saas::TranscribeAudioJob)
    end

    it 'keeps the previous flow for the recording of a call' do
      call = create(:message, account: account, inbox: inbox, conversation: conversation, content_type: :voice_call)
      expect(Messages::AudioTranscriptionJob).to receive(:perform_later)

      expect { attach_audio(call) }.not_to have_enqueued_job(Saas::TranscribeAudioJob)
    end

    it 'keeps the previous flow when the platform cannot transcribe for this account' do
      allow(Saas::Audio::TranscriptionService).to receive(:available_for?).with(account).and_return(false)
      expect(Messages::AudioTranscriptionJob).to receive(:perform_later)

      expect { attach_audio(received) }.not_to have_enqueued_job(Saas::TranscribeAudioJob)
    end
  end

  context 'when the account did not turn on the audio transcription' do
    it 'does not queue the credits based transcription' do
      allow(Saas::Audio::TranscriptionService).to receive(:available_for?).with(account).and_return(true)
      expect(Messages::AudioTranscriptionJob).to receive(:perform_later)

      expect { attach_audio(received) }.not_to have_enqueued_job(Saas::TranscribeAudioJob)
    end
  end

  context 'when an AI agent already listens to the audios of the inbox' do
    before do
      account.update!(audio_transcriptions: true)
      allow(Saas::Audio::TranscriptionService).to receive(:available_for?).with(account).and_return(true)
      account.saas_ai_agents.build.configure!(
        { name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true, audio_enabled: true },
        selected_inboxes: [inbox]
      )
    end

    it 'leaves the transcription to the agent so the audio is not charged twice' do
      expect(Messages::AudioTranscriptionJob).not_to receive(:perform_later)

      expect { attach_audio(received) }.not_to have_enqueued_job(Saas::TranscribeAudioJob)
    end
  end
end
