class Saas::TranscribeAudioJob < ApplicationJob
  queue_as :low

  # The social-media ingest saves the attachment before the file is attached.
  retry_on ActiveStorage::FileNotFoundError, wait: 2.seconds, attempts: 3

  def perform(attachment_id)
    attachment = Attachment.find_by(id: attachment_id)
    return if attachment.blank? || !attachment.audio?

    account = attachment.account
    return unless Saas::Audio::TranscriptionService.available_for?(account)

    result = Saas::Audio::TranscriptionService.new(attachment: attachment, account: account).perform
    raise ActiveStorage::FileNotFoundError if result[:error] == 'audio_not_attached'

    log_failure(attachment, result[:error]) unless result[:success]
  end

  private

  def log_failure(attachment, error)
    Rails.logger.info({ event: 'saas_audio_transcription_skipped', account_id: attachment.account_id,
                        attachment_id: attachment.id, error: error }.to_json)
  end
end
