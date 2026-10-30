require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:another_conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }

  # This inbox_member is used to establish the agent's access to the inbox
  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe '#perform' do
    context 'when user is an administrator' do
      it 'returns all conversations' do
        result = described_class.new(
          account.conversations,
          admin,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when user is an agent' do
      let(:colleague) { create(:user, account: account, role: :agent) }

      before { create(:inbox_member, user: colleague, inbox: inbox) }

      it 'returns only the conversations assigned to the agent' do
        conversation.update!(assignee: agent)
        another_conversation.update!(assignee: colleague)
        create(:conversation, account: account, inbox: inbox)

        result = described_class.new(account.conversations, agent, account).perform

        expect(result).to contain_exactly(conversation)
      end

      it 'does not return a conversation assigned to the agent in an inbox they are not a member of' do
        other_inbox_conversation = create(:conversation, account: account, inbox: create(:inbox, account: account), assignee: agent)

        result = described_class.new(account.conversations, agent, account).perform

        expect(result).not_to include(other_inbox_conversation)
      end

      it 'returns nothing when no conversation is assigned to the agent' do
        expect(described_class.new(account.conversations, agent, account).perform).to be_empty
      end
    end

    context 'when plan_hint_selective_filter is enabled' do
      let!(:other_inbox) { create(:inbox, account: account) }

      before { conversation.update!(assignee: agent) }
      let!(:inaccessible_conversation) { create(:conversation, account: account, inbox: other_inbox) }

      it 'returns the same conversations as the default scoping for an agent' do
        default_result = described_class.new(account.conversations, agent, account).perform
        hinted_result = described_class.new(account.conversations, agent, account, plan_hint_selective_filter: true).perform

        expect(hinted_result.to_a).to match_array(default_result.to_a)
        expect(hinted_result).not_to include(inaccessible_conversation)
      end

      it 'keeps the planner hint in the generated query' do
        hinted_result = described_class.new(account.conversations, agent, account, plan_hint_selective_filter: true).perform

        expect(hinted_result.to_sql).to include('conversations.inbox_id + 0')
      end

      it 'does not change administrator scoping' do
        result = described_class.new(account.conversations, admin, account, plan_hint_selective_filter: true).perform

        expect(result.to_sql).not_to include('inbox_id + 0')
        expect(result).to include(inaccessible_conversation)
      end
    end
  end
end
