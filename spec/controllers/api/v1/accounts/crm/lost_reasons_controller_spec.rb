require 'rails_helper'

RSpec.describe 'Crm lost reasons API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/crm/lost_reasons" }

  describe 'GET /crm/lost_reasons' do
    it 'lists the reasons of the account in order, for any member' do
      account.crm_lost_reasons.create!(name: 'Preço', position: 2)
      account.crm_lost_reasons.create!(name: 'Sem resposta', position: 1)
      create(:account).crm_lost_reasons.create!(name: 'De outra conta')

      get base_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('name')).to eq(['Sem resposta', 'Preço'])
    end
  end

  describe 'POST /crm/lost_reasons' do
    it 'lets an administrator register a reason at the end of the list' do
      account.crm_lost_reasons.create!(name: 'Preço', position: 4)

      post base_url, headers: admin.create_new_auth_token, params: { lost_reason: { name: 'Concorrente' } }, as: :json

      expect(response).to have_http_status(:created)
      expect(account.crm_lost_reasons.find_by(name: 'Concorrente')).to have_attributes(position: 5, active: true)
    end

    it 'does not accept repeated names' do
      account.crm_lost_reasons.create!(name: 'Preço')

      post base_url, headers: admin.create_new_auth_token, params: { lost_reason: { name: 'preço' } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'is not allowed for agents' do
      post base_url, headers: agent.create_new_auth_token, params: { lost_reason: { name: 'Preço' } }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH and DELETE /crm/lost_reasons/:id' do
    let!(:reason) { account.crm_lost_reasons.create!(name: 'Preço') }

    it 'renames and reorders a reason' do
      patch "#{base_url}/#{reason.id}", headers: admin.create_new_auth_token, params: { lost_reason: { name: 'Preço alto', position: 3 } }, as: :json

      expect(reason.reload).to have_attributes(name: 'Preço alto', position: 3)
    end

    it 'removes a reason nobody used' do
      delete "#{base_url}/#{reason.id}", headers: admin.create_new_auth_token, as: :json

      expect(account.crm_lost_reasons.exists?(reason.id)).to be(false)
    end

    it 'only deactivates a reason that deals already carry' do
      pipeline = account.crm_pipelines.create!(name: 'Comercial')
      stage = account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0)
      account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: create(:contact, account: account), name: 'Lead',
                                status: 'lost', lost_reason: reason)

      delete "#{base_url}/#{reason.id}", headers: admin.create_new_auth_token, as: :json

      expect(reason.reload.active).to be(false)
    end
  end

  describe 'marking a deal as lost' do
    let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
    let(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
    let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: create(:contact, account: account), name: 'Lead') }
    let(:deal_url) { "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}" }
    let!(:reason) { account.crm_lost_reasons.create!(name: 'Preço') }

    it 'asks for the reason' do
      patch deal_url, headers: admin.create_new_auth_token, params: { deal: { status: 'lost' } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(deal.reload.status).to eq('open')
    end

    it 'stores the reason and the note' do
      patch deal_url, headers: admin.create_new_auth_token, params: { deal: { status: 'lost', lost_reason_id: reason.id, lost_note: 'Caro' } }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['lost_reason']).to include('id' => reason.id, 'name' => 'Preço')
      expect(deal.reload).to have_attributes(status: 'lost', lost_reason_id: reason.id, lost_note: 'Caro')
    end
  end
end
