require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }

  let(:conversation) { create(:conversation, account: account) }

  permissions :destroy? do
    context 'when user is an administrator' do
      it 'allows destroy' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when user is an agent' do
      it 'denies destroy' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end
  end

  permissions :index? do
    context 'when user is authenticated' do
      it 'allows index' do
        expect(subject).to permit(agent_context, conversation)
      end
    end
  end

  permissions :show? do
    context 'when user is an administrator' do
      it 'allows access' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when the conversation is assigned to the agent' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

      before { create(:inbox_member, user: agent, inbox: inbox) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when the agent is in the inbox but the conversation is unassigned or belongs to someone else' do
      let(:inbox) { create(:inbox, account: account) }
      let(:colleague) { create(:user, account: account, role: :agent) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox) }
      let(:colleague_conversation) { create(:conversation, account: account, inbox: inbox, assignee: colleague) }

      before do
        create(:inbox_member, user: agent, inbox: inbox)
        create(:inbox_member, user: colleague, inbox: inbox)
      end

      it 'denies access to an unassigned conversation' do
        expect(subject).not_to permit(agent_context, conversation)
      end

      it 'denies access to a conversation assigned to a colleague' do
        expect(subject).not_to permit(agent_context, colleague_conversation)
      end
    end

    context 'when agent only shares the team of the conversation' do
      let(:team) { create(:team, account: account) }
      let(:conversation) { create(:conversation, :with_team, account: account, team: team) }

      before { create(:team_member, team: team, user: agent) }

      it 'denies access' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end

    context 'when agent lacks inbox and team access' do
      let(:conversation) { create(:conversation, account: account) }

      it 'denies access' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end
  end
end
