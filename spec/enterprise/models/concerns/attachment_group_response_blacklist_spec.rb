require 'rails_helper'

RSpec.describe Attachment do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     content_attributes: { participant: '5562999991111@s.whatsapp.net' })
  end

  before do
    conversation.contact_inbox.update!(source_id: '120363123456789@g.us')
    account.saas_ai_agents.build.configure!(
      { name: 'AI', system_prompt: 'Help', provider: 'openai', model: 'test-model', active: true,
        respond_to_groups: true, audio_enabled: false, group_response_blacklist: ['5562999991111'] }, selected_inboxes: [inbox]
    )
  end

  it 'does not enqueue independent transcription for a blacklisted participant even when agent audio is off' do
    expect(Messages::AudioTranscriptionJob).not_to receive(:perform_later)
    attachment = message.attachments.create!(account: account, file_type: :audio,
                                             file: fixture_file_upload('spec/assets/sample.mp3', 'audio/mpeg'))
    expect(attachment).to be_persisted
    expect(message.reload.attachments).to include(attachment)
  end

  it 'preserves independent transcription for staff audio notes in the same group' do
    note = create(:message, account: account, inbox: inbox, conversation: conversation, private: true,
                            message_type: :outgoing, sender: create(:user, account: account))
    expect(Messages::AudioTranscriptionJob).to receive(:perform_later)
    attachment = note.attachments.create!(account: account, file_type: :audio,
                                          file: fixture_file_upload('spec/assets/sample.mp3', 'audio/mpeg'))
    expect(attachment).to be_persisted
  end
end
