require 'rails_helper'

RSpec.describe 'Transcribe a received audio', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, content: nil) }
  let!(:attachment) do
    message.attachments.create!(account: account, file_type: :audio, file: fixture_file_upload('public/audio/widget/ding.mp3'),
                                meta: { 'duration' => 30 })
  end
  let(:url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/#{message.id}/transcribe" }
  let(:audio_env) { { SAAS_AUDIO_PROVIDER: 'openai', SAAS_AUDIO_MODEL: 'whisper-1', SAAS_AUDIO_API_KEY: 'test-key' } }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    Saas::Wallet.for_account(account, 'text_credits').credit!(units: 10, reference: 'transcribe-spec-credit')
  end

  def transcribe(attachment_id = attachment.id, user: agent)
    post url, headers: user.create_new_auth_token, params: { attachment_id: attachment_id }, as: :json
  end

  it 'queues the transcription of the audio' do
    with_modified_env(audio_env) do
      expect { transcribe }.to have_enqueued_job(Saas::TranscribeAudioJob).with(attachment.id)
    end

    expect(response).to have_http_status(:accepted)
  end

  it 'does not queue again when the audio already has a transcription' do
    attachment.update!(meta: { 'transcribed_text' => 'Já transcrito' })

    with_modified_env(audio_env) do
      expect { transcribe }.not_to have_enqueued_job(Saas::TranscribeAudioJob)
    end

    expect(response).to have_http_status(:ok)
  end

  it 'asks to add credits when the balance is not enough' do
    Saas::Wallet.for_account(account, 'text_credits').debit!(units: 10, reference: 'transcribe-spec-debit')

    with_modified_env(audio_env) do
      expect { transcribe }.not_to have_enqueued_job(Saas::TranscribeAudioJob)
    end

    expect(response).to have_http_status(:payment_required)
    expect(response.parsed_body['error']).to eq('insufficient_balance')
  end

  it 'tells when the transcription is not configured on the platform' do
    with_modified_env(audio_env.merge(SAAS_AUDIO_API_KEY: '')) do
      transcribe
    end

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('audio_not_configured')
  end

  it 'is refused when the account has no text AI' do
    account.disable_features!('text_ai')

    with_modified_env(audio_env) do
      transcribe
    end

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body['error']).to eq('text_ai_disabled')
  end

  it 'does not accept an attachment that is not an audio' do
    image = message.attachments.create!(account: account, file_type: :image, file: fixture_file_upload('spec/assets/avatar.png', 'image/png'))

    with_modified_env(audio_env) do
      transcribe(image.id)
    end

    expect(response).to have_http_status(:not_found)
  end

  it 'does not accept an attachment of another message' do
    other = create(:message, account: account, inbox: inbox, conversation: conversation)
    foreign = other.attachments.create!(account: account, file_type: :audio, file: fixture_file_upload('public/audio/widget/ding.mp3'))

    with_modified_env(audio_env) do
      transcribe(foreign.id)
    end

    expect(response).to have_http_status(:not_found)
  end

  it 'is not allowed for an agent who cannot see the conversation' do
    outsider = create(:user, account: account, role: :agent)

    with_modified_env(audio_env) do
      transcribe(user: outsider)
    end

    expect(response).to have_http_status(:unauthorized)
  end
end
