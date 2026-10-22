require 'rails_helper'

RSpec.describe 'Group message reactions', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox).reload }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, source_id: 'WAID:target') }
  let(:base_url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}" }
  let(:event) do
    { emoji: '✅', from_me: true, timestamp_ms: 1000, event_id: 'event', target_id: 'target', participant: '', group_jid: '120363000000001@g.us' }
  end

  before do
    allow(Evolution::Configuration).to receive(:new).and_return(instance_double(Evolution::Configuration, eligible?: true))
    allow(Evolution::GroupJidResolver).to receive(:call).and_return('120363000000001@g.us')
  end

  it 'rejects provider events without the private integration key' do
    with_modified_env EVOLUTION_API_KEY: 'test-secret' do
      post "#{base_url}/reaction_events", params: { reaction: event }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'links a provider event without creating a normal message' do
    message
    with_modified_env EVOLUTION_API_KEY: 'test-secret' do
      expect do
        post "#{base_url}/reaction_events", params: { reaction: event },
                                            headers: admin.create_new_auth_token.merge('X-Evolution-Reaction-Key' => 'test-secret'), as: :json
      end.not_to change(Message, :count)
      expect(response).to have_http_status(:ok)
      expect(message.reload.content_attributes['whatsapp_reactions'].sole['emoji']).to eq('✅')
    end
  end

  it 'links an individual provider event without requiring a group JID' do
    message
    individual_event = event.except(:group_jid).merge(participant: '5511999999999@s.whatsapp.net')
    allow(Evolution::GroupJidResolver).to receive(:call).and_return(nil)

    with_modified_env EVOLUTION_API_KEY: 'test-secret' do
      post "#{base_url}/reaction_events", params: { reaction: individual_event },
                                          headers: admin.create_new_auth_token.merge('X-Evolution-Reaction-Key' => 'test-secret'), as: :json
      expect(response).to have_http_status(:ok)
      expect(message.reload.content_attributes['whatsapp_reactions'].sole['emoji']).to eq('✅')
    end
  end

  it 'accepts unknown targets without creating a message or reaction' do
    with_modified_env EVOLUTION_API_KEY: 'test-secret' do
      post "#{base_url}/reaction_events", params: { reaction: event },
                                          headers: admin.create_new_auth_token.merge('X-Evolution-Reaction-Key' => 'test-secret'), as: :json
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to eq('ignored' => 'target_not_found')
    end
  end

  it 'does not accept a message belonging to another account' do
    other_conversation = create(:conversation).reload
    other = create(:message, account: other_conversation.account, inbox: other_conversation.inbox, conversation: other_conversation)
    post "#{base_url}/messages/#{other.id}/reaction", params: { emoji: '👍' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'validates outbound emojis before calling the provider' do
    message
    expect(Evolution::MessageReactionsService).not_to receive(:new)
    post "#{base_url}/messages/#{message.id}/reaction", params: { emoji: 'text' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
