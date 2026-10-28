require 'rails_helper'

RSpec.describe Saas::TranscribeAudioJob do
  let(:account) { create(:account) }
  let(:message) { create(:message, account: account) }
  let(:attachment) do
    message.attachments.create!(account: account, file_type: :audio, file: fixture_file_upload('public/audio/widget/ding.mp3'))
  end
  let(:service) { instance_double(Saas::Audio::TranscriptionService) }

  before do
    allow(Saas::Audio::TranscriptionService).to receive(:available_for?).with(account).and_return(true)
    allow(Saas::Audio::TranscriptionService).to receive(:new).with(attachment: attachment, account: account).and_return(service)
    allow(service).to receive(:perform).and_return(success: true, text: 'Olá')
  end

  it 'is queued on the low priority queue' do
    expect { described_class.perform_later(attachment.id) }.to have_enqueued_job(described_class).with(attachment.id).on_queue('low')
  end

  it 'transcribes the audio without an AI agent' do
    described_class.perform_now(attachment.id)

    expect(service).to have_received(:perform)
  end

  it 'does nothing when the attachment is gone' do
    expect { described_class.perform_now(0) }.not_to raise_error
    expect(service).not_to have_received(:perform)
  end

  it 'does nothing for an attachment that is not an audio' do
    image = message.attachments.create!(account: account, file_type: :image, file: fixture_file_upload('spec/assets/avatar.png', 'image/png'))

    described_class.perform_now(image.id)

    expect(service).not_to have_received(:perform)
  end

  it 'does nothing when the account can no longer use text AI' do
    allow(Saas::Audio::TranscriptionService).to receive(:available_for?).with(account).and_return(false)

    described_class.perform_now(attachment.id)

    expect(service).not_to have_received(:perform)
  end

  it 'does not raise when the transcription could not be done, for example without credits' do
    allow(service).to receive(:perform).and_return(success: false, error: 'insufficient_balance')

    expect { described_class.perform_now(attachment.id) }.not_to raise_error
  end

  it 'retries while the file is not attached yet' do
    allow(service).to receive(:perform).and_return(success: false, error: 'audio_not_attached')

    expect { described_class.perform_now(attachment.id) }.to have_enqueued_job(described_class).with(attachment.id)
  end
end
