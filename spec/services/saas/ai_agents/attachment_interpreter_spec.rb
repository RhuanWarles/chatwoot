require 'rails_helper'

RSpec.describe Saas::AiAgents::AttachmentInterpreter do
  let(:message) { create(:message, content: nil) }

  it 'extracts text from text attachments' do
    message.attachments.create!(account: message.account, file_type: :file,
                                file: fixture_file_upload('spec/assets/attachment.pdf', 'application/pdf'))

    result = described_class.call(message)

    expect(result[:text]).to include('[Arquivo: attachment.pdf]')
  end

  it 'does not include audio because audio is handled by transcription' do
    message.attachments.create!(account: message.account, file_type: :audio,
                                meta: { 'transcribed_text' => 'Olá' })

    expect(described_class.call(message)).to eq(text: nil, images: [])
  end
end
