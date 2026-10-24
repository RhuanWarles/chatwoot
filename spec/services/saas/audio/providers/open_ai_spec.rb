require 'rails_helper'

RSpec.describe Saas::Audio::Providers::OpenAi, type: :service do
  let(:message) { create(:message, content: nil) }
  let(:attachment) do
    message.attachments.create!(
      account: message.account,
      file_type: :audio,
      file: fixture_file_upload('spec/assets/sample.ogg', 'audio/opus', false)
    )
  end

  before do
    attachment.file.blob.update!(filename: 'voice.oga', content_type: 'audio/opus')
  end

  it 'sends Ogg/Opus audio with supported filename and MIME metadata' do
    request = stub_request(:post, 'https://api.openai.com/v1/audio/transcriptions')
              .with do |req|
                expect(req.headers['Content-Type']).to match(%r{\Amultipart/form-data; boundary=})
                expect(req.body).to include(
                  'name="model"', 'gpt-transcribe', 'name="file"; filename="audio.ogg"',
                  'Content-Type: audio/ogg', 'Content-Length:'
                )
              end
              .to_return(status: 200, body: { text: 'Olá' }.to_json, headers: { 'Content-Type' => 'application/json' })

    provider = described_class.new(api_key: 'test-key', model: 'gpt-transcribe')
    result = provider.transcribe(blob: attachment.file.blob)

    expect(result).to eq('Olá')
    expect(request).to have_been_requested
    expect(provider.request_metadata).to include(
      endpoint: '/audio/transcriptions', method: 'POST', model: 'gpt-transcribe', field: 'file',
      filename: 'audio.ogg', content_type: 'audio/ogg', byte_size: attachment.file.blob.byte_size,
      parameters: { temperature: 0.0 }
    )
  end
end
