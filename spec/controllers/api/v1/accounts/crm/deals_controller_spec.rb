require 'rails_helper'

RSpec.describe 'Crm deals API for agents', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:contact) { create(:contact, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/crm/deals" }
  let!(:own_deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Meu', owner: agent) }
  let!(:colleague_deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Do colega', owner: colleague) }

  describe 'GET /crm/deals' do
    it 'lists only the cards the agent owns' do
      get base_url, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body.pluck('name')).to eq(['Meu'])
    end

    it 'lists every card for an administrator' do
      get base_url, headers: administrator.create_new_auth_token, as: :json

      expect(response.parsed_body.pluck('name')).to contain_exactly('Meu', 'Do colega')
    end

    it 'does not find the cards of a colleague through the contact filter or the search' do
      get base_url, headers: agent.create_new_auth_token, params: { contact_id: contact.id, q: 'colega' }, as: :json

      expect(response.parsed_body).to be_empty
    end
  end

  describe 'GET and PATCH /crm/deals/:id' do
    it 'answers 404 for a card of a colleague' do
      get "#{base_url}/#{colleague_deal.id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)

      patch "#{base_url}/#{colleague_deal.id}", headers: agent.create_new_auth_token, params: { deal: { name: 'Roubado' } }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(colleague_deal.reload.name).to eq('Do colega')
    end

    it 'does not let the agent hand the card to someone else or take its owner away' do
      patch "#{base_url}/#{own_deal.id}", headers: agent.create_new_auth_token,
                                          params: { deal: { name: 'Renomeado', owner_id: colleague.id } }, as: :json

      expect(response).to have_http_status(:success)
      expect(own_deal.reload).to have_attributes(name: 'Renomeado', owner_id: agent.id)
    end

    it 'lets an administrator change the owner' do
      patch "#{base_url}/#{own_deal.id}", headers: administrator.create_new_auth_token, params: { deal: { owner_id: colleague.id } }, as: :json

      expect(own_deal.reload.owner_id).to eq(colleague.id)
    end
  end

  describe 'POST /crm/deals' do
    let(:params) { { deal: { name: 'Novo card', pipeline_id: pipeline.id, pipeline_stage_id: stage.id, contact_id: contact.id } } }

    it 'always creates the card of an agent in their own name' do
      post base_url, headers: agent.create_new_auth_token, params: params.deep_merge(deal: { owner_id: colleague.id }), as: :json

      expect(response).to have_http_status(:created)
      expect(account.crm_deals.find_by(name: 'Novo card').owner_id).to eq(agent.id)
    end

    it 'keeps the owner an administrator chooses' do
      post base_url, headers: administrator.create_new_auth_token, params: params.deep_merge(deal: { owner_id: colleague.id }), as: :json

      expect(account.crm_deals.find_by(name: 'Novo card').owner_id).to eq(colleague.id)
    end
  end
end
