require 'rails_helper'

RSpec.describe 'Agents inboxes, screens and manual confirmation', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/agents" }

  def auth(user = admin)
    { headers: user.create_new_auth_token, as: :json }
  end

  describe 'POST /agents' do
    let(:params) { { name: 'Brenda', email: 'brenda@example.com', role: 'agent' } }

    it 'puts the new agent in the chosen inboxes of the account' do
      foreign_inbox = create(:inbox, account: create(:account))

      post base_url, params: { agent: params.merge(inbox_ids: [inbox.id, other_inbox.id, foreign_inbox.id]) }, **auth

      expect(response).to have_http_status(:success)
      user = User.find_by(email: 'brenda@example.com')
      expect(inbox.members).to include(user)
      expect(other_inbox.members).to include(user)
      expect(foreign_inbox.members).not_to include(user)
      expect(response.parsed_body['inbox_ids']).to match_array([inbox.id, other_inbox.id])
    end

    it 'does not touch the inboxes when none are sent' do
      post base_url, params: { agent: params }, **auth

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['inbox_ids']).to eq([])
      expect(inbox.members).to be_empty
    end

    it 'saves the screens the agent can open' do
      post base_url, params: { agent: params.merge(allowed_screens: %w[conversations crm]) }, **auth

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['allowed_screens']).to eq(%w[conversations crm])
    end

    it 'gives access to every screen by default' do
      post base_url, params: { agent: params }, **auth

      expect(response.parsed_body['allowed_screens']).to be_nil
    end

    it 'refuses screens that do not exist' do
      post base_url, params: { agent: params.merge(allowed_screens: %w[conversations billing]) }, **auth

      expect(response).to have_http_status(:unprocessable_entity)
      expect(User.find_by(email: 'brenda@example.com')&.account_users).to be_blank
    end

    it 'is reserved for administrators' do
      post base_url, params: { agent: params }, **auth(agent)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /agents/:id' do
    before do
      inbox.add_members([agent.id])
    end

    it 'moves the agent to exactly the chosen inboxes' do
      patch "#{base_url}/#{agent.id}", params: { agent: { inbox_ids: [other_inbox.id] } }, **auth

      expect(response).to have_http_status(:success)
      expect(inbox.reload.members).not_to include(agent)
      expect(other_inbox.reload.members).to include(agent)
      expect(response.parsed_body['inbox_ids']).to eq([other_inbox.id])
    end

    it 'removes the agent from every inbox when the list is empty' do
      patch "#{base_url}/#{agent.id}", params: { agent: { inbox_ids: [] } }, **auth

      expect(inbox.reload.members).not_to include(agent)
    end

    it 'keeps the inboxes when the list is not sent' do
      patch "#{base_url}/#{agent.id}", params: { agent: { name: 'Novo nome' } }, **auth

      expect(inbox.reload.members).to include(agent)
      expect(agent.reload.name).to eq('Novo nome')
    end

    it 'does not remove the agent from inboxes of other accounts' do
      other_account = create(:account)
      foreign_inbox = create(:inbox, account: other_account)
      create(:account_user, account: other_account, user: agent)
      foreign_inbox.add_members([agent.id])

      patch "#{base_url}/#{agent.id}", params: { agent: { inbox_ids: [] } }, **auth

      expect(foreign_inbox.reload.members).to include(agent)
    end

    it 'limits the screens and then gives access to everything again' do
      patch "#{base_url}/#{agent.id}", params: { agent: { allowed_screens: ['contacts'] } }, **auth
      expect(agent.account_users.find_by(account: account).allowed_screens).to eq(['contacts'])

      patch "#{base_url}/#{agent.id}", params: { agent: { allowed_screens: nil } }, **auth
      expect(agent.account_users.find_by(account: account).allowed_screens).to be_nil
    end

    it 'treats an empty list of screens as access to everything' do
      patch "#{base_url}/#{agent.id}", params: { agent: { allowed_screens: ['crm'] } }, **auth
      patch "#{base_url}/#{agent.id}", params: { agent: { allowed_screens: [] } }, **auth

      expect(agent.account_users.find_by(account: account).allowed_screens).to be_nil
    end
  end

  describe 'GET /agents' do
    it 'lists the inboxes and screens of every agent' do
      inbox.add_members([agent.id])
      agent.account_users.find_by(account: account).update!(allowed_screens: ['inbox'])

      get base_url, **auth

      listed = response.parsed_body.find { |item| item['id'] == agent.id }
      expect(listed['inbox_ids']).to eq([inbox.id])
      expect(listed['allowed_screens']).to eq(['inbox'])
      expect(response.parsed_body.find { |item| item['id'] == admin.id }['inbox_ids']).to eq([])
    end
  end

  describe 'the signed in user' do
    it 'receives the screens it can open with its profile' do
      agent.account_users.find_by(account: account).update!(allowed_screens: %w[crm calls])

      get '/api/v1/profile', headers: agent.create_new_auth_token, as: :json

      account_data = response.parsed_body['accounts'].find { |item| item['id'] == account.id }
      expect(account_data['allowed_screens']).to eq(%w[crm calls])
    end
  end

  describe 'POST /agents/:id/confirm' do
    it 'lets an administrator confirm an agent whose e-mail never arrived' do
      pending_agent = create(:user, account: account, role: :agent, confirmed_at: nil)
      expect(pending_agent.reload).not_to be_confirmed

      post "#{base_url}/#{pending_agent.id}/confirm", **auth

      expect(response).to have_http_status(:success)
      expect(pending_agent.reload).to be_confirmed
      expect(response.parsed_body['confirmed']).to be(true)
    end

    it 'does nothing to an agent that is already confirmed' do
      post "#{base_url}/#{agent.id}/confirm", **auth

      expect(response).to have_http_status(:success)
      expect(agent.reload).to be_confirmed
    end

    it 'is reserved for administrators' do
      pending_agent = create(:user, account: account, role: :agent, confirmed_at: nil)

      post "#{base_url}/#{pending_agent.id}/confirm", **auth(agent)

      expect(response).to have_http_status(:unauthorized)
      expect(pending_agent.reload).not_to be_confirmed
    end

    it 'does not reach agents of other accounts' do
      foreign_agent = create(:user, account: create(:account), role: :agent, confirmed_at: nil)

      post "#{base_url}/#{foreign_agent.id}/confirm", **auth

      expect(response).to have_http_status(:not_found)
      expect(foreign_agent.reload).not_to be_confirmed
    end
  end
end
