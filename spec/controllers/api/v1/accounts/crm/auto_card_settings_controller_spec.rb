require 'rails_helper'

RSpec.describe 'Crm auto card settings API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/auto_card_settings" }

  it 'shows the defaults to an administrator' do
    get url, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body).to eq('enabled' => true, 'pipeline_id' => nil, 'stage_id' => nil)
  end

  it 'saves the pipeline and the stage' do
    patch url, headers: administrator.create_new_auth_token,
               params: { auto_card_settings: { enabled: true, pipeline_id: pipeline.id, stage_id: stage.id } }, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('enabled' => true, 'pipeline_id' => pipeline.id, 'stage_id' => stage.id)
  end

  it 'saves the switch' do
    patch url, headers: administrator.create_new_auth_token, params: { auto_card_settings: { enabled: false } }, as: :json

    expect(response.parsed_body['enabled']).to be(false)
  end

  it 'answers 422 for a stage that is not of the pipeline' do
    other_pipeline = account.crm_pipelines.create!(name: 'Outro')

    patch url, headers: administrator.create_new_auth_token,
               params: { auto_card_settings: { enabled: true, pipeline_id: other_pipeline.id, stage_id: stage.id } }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to be_present
  end

  it 'is not allowed for agents' do
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    patch url, headers: agent.create_new_auth_token, params: { auto_card_settings: { enabled: false } }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
