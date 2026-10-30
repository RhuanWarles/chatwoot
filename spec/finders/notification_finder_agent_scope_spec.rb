require 'rails_helper'

RSpec.describe NotificationFinder, 'agent scope' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:own_conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let(:lost_conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:own_notification) { create(:notification, account: account, user: agent, primary_actor: own_conversation) }
  let!(:lost_notification) { create(:notification, account: account, user: agent, primary_actor: lost_conversation) }

  before { create(:inbox_member, inbox: inbox, user: agent) }

  it 'hides the notifications of conversations the agent can no longer open' do
    expect(described_class.new(agent, account, {}).notifications).to contain_exactly(own_notification)
  end

  it 'counts only what the agent can open' do
    finder = described_class.new(agent, account, {})

    expect([finder.count, finder.unread_count]).to eq([1, 1])
  end

  it 'keeps everything for an administrator' do
    administrator = create(:user, account: account, role: :administrator)
    create(:notification, account: account, user: administrator, primary_actor: lost_conversation)

    expect(described_class.new(administrator, account, {}).notifications.count).to eq(1)
  end
end
