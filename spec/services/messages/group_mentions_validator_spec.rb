require 'rails_helper'

RSpec.describe Messages::GroupMentionsValidator do
  let(:inbox) { instance_double(Inbox, api?: true) }
  let(:contact) { instance_double(Contact, identifier: '120363000000001@g.us') }
  let(:contact_inbox) { instance_double(ContactInbox, source_id: 'contact-source-uuid') }
  let(:conversation) { instance_double(Conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:participant) do
    { lid: '247613823709228@lid', jid: '5519994212713@s.whatsapp.net', phone: '5519994212713', display_name: 'Fernando Murilo' }
  end
  let(:participants_service) { instance_double(Evolution::GroupParticipantsService, perform: [participant]) }
  let(:mention) { participant.merge(start: 3, end: 19).stringify_keys }
  let(:params) do
    ActionController::Parameters.new(content: 'Oi @Fernando Murilo', content_attributes: { whatsapp_mentions: [mention], in_reply_to: 123 })
  end

  before do
    allow(Evolution::GroupParticipantsService).to receive(:new).with(conversation).and_return(participants_service)
  end

  it 'preserves valid mentions and existing reply metadata' do
    described_class.new(conversation, params).validate!
    expect(params[:content_attributes][:whatsapp_mentions].first[:lid]).to eq(participant[:lid])
    expect(params[:content_attributes][:in_reply_to]).to eq(123)
  end

  it 'supports JSON attributes used by attachment uploads' do
    params[:content_attributes] = params[:content_attributes].to_unsafe_h.to_json
    described_class.new(conversation, params).validate!
    expect(params[:content_attributes][:whatsapp_mentions].first[:jid]).to eq(participant[:jid])
  end

  it 'rejects metadata for a deleted or edited mention' do
    params[:content] = 'Oi Fernando'
    expect { described_class.new(conversation, params).validate! }.to raise_error(ArgumentError)
  end

  it 'rejects a participant that is not in this conversation group' do
    mention['lid'] = '999999999999999@lid'
    params[:content_attributes][:whatsapp_mentions] = [mention]
    expect { described_class.new(conversation, params).validate! }.to raise_error(ArgumentError)
  end

  it 'rejects a non-group conversation' do
    allow(contact).to receive(:identifier).and_return('5519994212713@s.whatsapp.net')
    expect { described_class.new(conversation, params).validate! }.to raise_error(ArgumentError)
    expect(participants_service).not_to have_received(:perform)
  end

  it 'rejects a private note' do
    params[:private] = true
    expect { described_class.new(conversation, params).validate! }.to raise_error(ArgumentError)
  end

  it 'rejects incoming metadata on this outbound entry point' do
    params[:message_type] = 'incoming'
    expect { described_class.new(conversation, params).validate! }.to raise_error(ArgumentError)
  end

  it 'does not fetch participants for messages without mentions' do
    params[:content_attributes].delete(:whatsapp_mentions)
    described_class.new(conversation, params).validate!
    expect(participants_service).not_to have_received(:perform)
  end

  it 'preserves the existing handling of malformed legacy content attributes' do
    params[:content_attributes] = '{invalid'
    expect { described_class.new(conversation, params).validate! }.not_to raise_error
  end

  it 'rejects overlapping mentions' do
    params[:content_attributes][:whatsapp_mentions] = [mention, mention]
    expect { described_class.new(conversation, params).validate! }.to raise_error(ArgumentError)
  end
end
