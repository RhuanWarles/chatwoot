require 'rails_helper'

RSpec.describe Conversations::PinnedNoteService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  def create_note(content, sender: agent, **attributes)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, private: true,
                     content: content, sender: sender, **attributes)
  end

  def pinned
    conversation.reload.additional_attributes['pinned_note']
  end

  describe 'a new internal note' do
    it 'goes on top of the conversation with a copy of the text and its author' do
      note = create_note('Cliente só atende depois das 18h')

      expect(pinned).to include('message_id' => note.id, 'content' => 'Cliente só atende depois das 18h', 'auto' => true)
      expect(pinned['author']).to eq('id' => agent.id, 'name' => agent.name)
      expect(pinned).not_to have_key('pinned_by')
    end

    it 'replaces the note that was on top before' do
      create_note('Primeira nota')
      latest = create_note('Segunda nota')

      expect(pinned).to include('message_id' => latest.id, 'content' => 'Segunda nota')
    end

    it 'keeps the other attributes of the conversation' do
      conversation.update!(additional_attributes: { 'browser_language' => 'pt-BR' })

      create_note('Nota')

      expect(conversation.reload.additional_attributes).to include('browser_language' => 'pt-BR', 'pinned_note' => anything)
    end

    it 'is also kept when the author is not an agent' do
      note = create_note('Resumo da conversa', sender: nil)

      expect(pinned).to include('message_id' => note.id)
      expect(pinned['author']).to be_nil
    end

    it 'cuts a very long note' do
      create_note('a' * 800)

      expect(pinned['content'].length).to eq(described_class::CONTENT_LIMIT)
    end

    it 'tells the other agents through the conversation update event' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      create_note('Nota')

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with('conversation.updated', anything, hash_including(:conversation))
    end
  end

  describe 'a message that is not an internal note' do
    it 'does not touch what is on top' do
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                       content: 'Olá!', sender: agent)
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                       content: 'Oi', sender: conversation.contact)

      expect(pinned).to be_nil
    end

    it 'ignores a note without text' do
      create_note(nil)

      expect(pinned).to be_nil
    end
  end

  describe 'a note an agent pinned on purpose' do
    it 'stays on top when a newer note arrives' do
      kept = create_note('Importante')
      described_class.new(conversation).pin(kept, agent)

      create_note('Nota mais nova')

      expect(pinned).to include('message_id' => kept.id)
      expect(pinned['pinned_by']).to eq('id' => agent.id, 'name' => agent.name)
    end

    it 'is replaced by the next note once it was unpinned' do
      kept = create_note('Importante')
      described_class.new(conversation).pin(kept, agent)
      conversation.update!(additional_attributes: conversation.additional_attributes.except('pinned_note'))

      latest = create_note('Nota mais nova')

      expect(pinned).to include('message_id' => latest.id, 'auto' => true)
    end
  end
end
