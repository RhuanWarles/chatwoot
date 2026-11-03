require 'rails_helper'

RSpec.describe SearchService, 'agent scope' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'Cliente Procurado') }
  let!(:own_conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: agent) }
  let!(:colleague_conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: colleague) }
  let!(:unassigned_conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  before do
    Current.account = account
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: colleague)
    [own_conversation, colleague_conversation, unassigned_conversation].each do |conversation|
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: "Quero o plano #{conversation.id}")
    end
  end

  after do
    Current.account = nil
  end

  def search(user, type)
    described_class.new(current_user: user, current_account: account, params: { q: 'Procurado' }, search_type: type).perform
  end

  it 'finds only the conversations assigned to the agent' do
    expect(search(agent, 'Conversation')[:conversations]).to contain_exactly(own_conversation)
  end

  it 'finds only the messages of the conversations assigned to the agent' do
    result = described_class.new(current_user: agent, current_account: account, params: { q: 'plano' }, search_type: 'Message').perform

    expect(result[:messages].map(&:conversation_id)).to eq([own_conversation.id])
  end

  it 'finds every conversation for an administrator' do
    administrator = create(:user, account: account, role: :administrator)

    expect(search(administrator, 'Conversation')[:conversations]).to contain_exactly(own_conversation, colleague_conversation, unassigned_conversation)
  end
end
