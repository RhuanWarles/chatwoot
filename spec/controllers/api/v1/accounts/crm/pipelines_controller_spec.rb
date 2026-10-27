require 'rails_helper'

RSpec.describe 'Crm pipelines automations API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:sellers) { create_list(:user, 2, account: account, role: :agent) }
  let(:segment) { account.crm_custom_fields.create!(name: 'Segmento', key: 'segmento', field_type: 'select', options: %w[Restaurante Clínica]) }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}" }

  def update_pipeline(params)
    patch url, headers: admin.create_new_auth_token, params: { pipeline: params }, as: :json
  end

  it 'stores random assignment, field routing and field automations' do
    route = { operator: 'equals', value: 'Restaurante', pipeline_id: pipeline.id, stage_id: stage.id }
    update_pipeline(
      field_automations: [
        { type: 'route_by_field', custom_field_id: segment.id, routes: [route], fallback: { pipeline_id: pipeline.id, stage_id: stage.id } },
        { type: 'add_label', label: 'vip', condition: { custom_field_id: segment.id, operator: 'equals', value: 'Restaurante' } }
      ]
    )

    expect(response).to have_http_status(:success)
    stored = pipeline.reload.field_automations
    expect(stored.first).to include('type' => 'route_by_field', 'custom_field_id' => segment.id)
    expect(stored.first['routes']).to eq([route.stringify_keys])
    expect(stored.first['fallback']).to eq('pipeline_id' => pipeline.id, 'stage_id' => stage.id)
    expect(stored.second['condition']).to include('operator' => 'equals', 'value' => 'Restaurante')
  end

  it 'stores a random assignment between several sellers on a stage' do
    patch "#{url}/stages/#{stage.id}",
          headers: admin.create_new_auth_token,
          params: { pipeline_stage: { automations: [{ type: 'assign_random', user_ids: sellers.map(&:id) }] } },
          as: :json

    expect(response).to have_http_status(:success)
    expect(stage.reload.automations).to eq([{ 'type' => 'assign_random', 'user_ids' => sellers.map(&:id) }])
  end

  it 'stores the value of a field the automation fills, including lists' do
    interests = account.crm_custom_fields.create!(name: 'Interesses', key: 'interesses', field_type: 'multiselect', options: %w[Site App])
    update_pipeline(
      won_automations: [{ type: 'set_field', custom_field_id: interests.id, value: %w[Site App] }]
    )

    expect(response).to have_http_status(:success)
    expect(pipeline.reload.won_automations).to eq([{ 'type' => 'set_field', 'custom_field_id' => interests.id, 'value' => %w[Site App] }])
  end

  it 'rejects an automation that points to something outside the account' do
    update_pipeline(field_automations: [{ type: 'assign_random', user_ids: [create(:user).id] }])

    expect(response).to have_http_status(:unprocessable_entity)
    expect(pipeline.reload.field_automations).to eq([])
  end

  it 'exposes the field automations when listing pipelines' do
    pipeline.update!(field_automations: [{ 'type' => 'add_label', 'label' => 'vip' }])

    get "/api/v1/accounts/#{account.id}/crm/pipelines", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body.first['field_automations']).to eq([{ 'type' => 'add_label', 'label' => 'vip' }])
  end
end
