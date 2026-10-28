require 'rails_helper'

RSpec.describe 'Pinned internal note', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}" }
  let!(:note) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, private: true,
                     content: 'Cliente só atende depois das 18h', sender: agent)
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    # a new internal note is pinned on its own; these examples start from a conversation with nothing pinned
    conversation.update!(additional_attributes: {})
  end

  def pin(message_id, user: agent)
    post "#{base_url}/pin_note", headers: user.create_new_auth_token, params: { message_id: message_id }, as: :json
  end

  def pinned
    conversation.reload.additional_attributes['pinned_note']
  end

  describe 'POST /conversations/:id/pin_note' do
    it 'pins an internal note, keeping a copy of the text and who pinned it' do
      pin(note.id)

      expect(response).to have_http_status(:success)
      expect(pinned).to include('message_id' => note.id, 'content' => 'Cliente só atende depois das 18h')
      expect(pinned['pinned_by']).to eq('id' => agent.id, 'name' => agent.name)
      expect(response.parsed_body['additional_attributes']['pinned_note']['message_id']).to eq(note.id)
    end

    it 'keeps the other attributes of the conversation' do
      conversation.update!(additional_attributes: { 'browser_language' => 'pt-BR' })

      pin(note.id)

      expect(conversation.reload.additional_attributes).to include('browser_language' => 'pt-BR', 'pinned_note' => anything)
    end

    it 'replaces the note that was pinned before' do
      other = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, private: true,
                               content: 'Outra nota', sender: agent)
      pin(note.id)

      pin(other.id)

      expect(pinned['message_id']).to eq(other.id)
    end

    it 'cuts a very long note' do
      note.update!(content: 'a' * 800)

      pin(note.id)

      expect(pinned['content'].length).to eq(500)
    end

    it 'does not pin a message the customer can see' do
      public_reply = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                                      content: 'Olá!', sender: agent)

      pin(public_reply.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(pinned).to be_nil
    end

    it 'does not pin a note that was deleted' do
      note.update!(content_attributes: { 'deleted' => true })

      pin(note.id)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does not pin a message of another conversation' do
      other_conversation = create(:conversation, account: account, inbox: inbox)
      foreign = create(:message, account: account, inbox: inbox, conversation: other_conversation, message_type: :outgoing,
                                 private: true, content: 'De outra conversa', sender: agent)

      pin(foreign.id)

      expect(response).to have_http_status(:not_found)
      expect(pinned).to be_nil
    end

    it 'is not allowed for an agent who cannot see the conversation' do
      outsider = create(:user, account: account, role: :agent)

      pin(note.id, user: outsider)

      expect(response).to have_http_status(:unauthorized)
      expect(pinned).to be_nil
    end

    it 'tells the other agents through the conversation update event' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      pin(note.id)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with('conversation.updated', anything, hash_including(:conversation))
    end
  end

  describe 'DELETE /conversations/:id/pin_note' do
    it 'removes the pinned note and keeps the note itself' do
      pin(note.id)

      delete "#{base_url}/pin_note", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(pinned).to be_nil
      expect(response.parsed_body['additional_attributes']).not_to have_key('pinned_note')
      expect(Message.exists?(note.id)).to be(true)
    end

    it 'is fine when nothing was pinned' do
      delete "#{base_url}/pin_note", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
    end
  end

  describe 'deleting the pinned note' do
    it 'unpins it' do
      pin(note.id)

      delete "#{base_url}/messages/#{note.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(pinned).to be_nil
    end

    it 'does not touch a pin that is a different note' do
      other = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, private: true,
                               content: 'Outra nota', sender: agent)
      pin(other.id)

      delete "#{base_url}/messages/#{note.id}", headers: admin.create_new_auth_token, as: :json

      expect(pinned['message_id']).to eq(other.id)
    end
  end
end
