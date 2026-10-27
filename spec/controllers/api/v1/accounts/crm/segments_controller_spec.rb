require 'rails_helper'

RSpec.describe 'Crm segments API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/crm/segments" }

  describe 'GET /crm/segments' do
    it 'lists the segments of the account in order, for any member' do
      account.crm_segments.create!(name: 'Clínicas', position: 2)
      account.crm_segments.create!(name: 'Restaurantes', position: 1)
      create(:account).crm_segments.create!(name: 'De outra conta')

      get base_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('name')).to eq(%w[Restaurantes Clínicas])
    end

    it 'needs a signed in user' do
      get base_url, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /crm/segments' do
    it 'lets an administrator register a segment' do
      post base_url, headers: admin.create_new_auth_token, params: { segment: { name: 'Restaurantes', color: '#ff0000' } }, as: :json

      expect(response).to have_http_status(:created)
      expect(account.crm_segments.find_by(name: 'Restaurantes')).to have_attributes(color: '#ff0000', active: true)
    end

    it 'puts new segments at the end of the list' do
      account.crm_segments.create!(name: 'Primeiro', position: 4)

      post base_url, headers: admin.create_new_auth_token, params: { segment: { name: 'Segundo' } }, as: :json

      expect(account.crm_segments.find_by(name: 'Segundo').position).to eq(5)
    end

    it 'does not accept repeated names' do
      account.crm_segments.create!(name: 'Restaurantes')

      post base_url, headers: admin.create_new_auth_token, params: { segment: { name: 'restaurantes' } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'is not allowed for agents' do
      post base_url, headers: agent.create_new_auth_token, params: { segment: { name: 'Restaurantes' } }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(account.crm_segments.count).to eq(0)
    end
  end

  describe 'PATCH and DELETE /crm/segments/:id' do
    let!(:segment) { account.crm_segments.create!(name: 'Restaurantes') }
    let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
    let(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }

    def create_deal_in(segment)
      account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: create(:contact, account: account),
                                name: 'Lead', segment: segment)
    end

    it 'renames a segment' do
      patch "#{base_url}/#{segment.id}", headers: admin.create_new_auth_token, params: { segment: { name: 'Bares' } }, as: :json

      expect(response).to have_http_status(:success)
      expect(segment.reload.name).to eq('Bares')
    end

    it 'removes a segment no deal uses' do
      delete "#{base_url}/#{segment.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(Crm::Segment.exists?(segment.id)).to be(false)
    end

    it 'keeps a segment that deals use, only deactivating it' do
      deal = create_deal_in(segment)

      delete "#{base_url}/#{segment.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(segment.reload.active).to be(false)
      expect(deal.reload.segment).to eq(segment)
    end

    it 'does not touch segments of other accounts' do
      foreign = create(:account).crm_segments.create!(name: 'Outra')

      delete "#{base_url}/#{foreign.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Crm::Segment.exists?(foreign.id)).to be(true)
    end
  end

  describe 'deals' do
    let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
    let(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
    let(:segment) { account.crm_segments.create!(name: 'Clínicas', color: '#00aa00') }
    let(:contact) { create(:contact, account: account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:deals_url) { "/api/v1/accounts/#{account.id}/crm/deals" }

    it 'carry a segment chosen when the deal is created and listed' do
      post deals_url, headers: admin.create_new_auth_token, as: :json,
                      params: { deal: { name: 'Lead', pipeline_id: pipeline.id, pipeline_stage_id: stage.id, contact_id: contact.id,
                                        segment_id: segment.id } }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['segment']).to include('id' => segment.id, 'name' => 'Clínicas')

      get deals_url, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body.first['segment']).to include('name' => 'Clínicas', 'color' => '#00aa00')
    end

    it 'say who answered the customer, apart from the owner of the deal' do
      brenda = create(:user, account: account, role: :agent)
      rodolpho = create(:user, account: account, role: :agent)
      account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead', owner: brenda)
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: rodolpho)
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                       content_attributes: { 'generated_by_ai' => true })

      get deals_url, headers: admin.create_new_auth_token, as: :json

      deal = response.parsed_body.first
      expect(deal['owner_id']).to eq(brenda.id)
      expect(deal['answered_by']).to eq('user_ids' => [rodolpho.id], 'ai' => true)
    end

    it 'say nobody answered a customer that got no reply' do
      account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead')

      get deals_url, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body.first['answered_by']).to eq('user_ids' => [], 'ai' => false)
    end
  end
end
