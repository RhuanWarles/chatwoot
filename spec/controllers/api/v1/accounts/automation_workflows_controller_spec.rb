require 'rails_helper'

RSpec.describe 'Automation workflows API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/automation_workflows" }
  let(:graph) do
    {
      nodes: [{ id: 't', type: 'trigger', position: { x: 0, y: 0 }, data: { event: 'crm_deal_lost' } },
              { id: 'a', type: 'action', position: { x: 200, y: 0 }, data: { action: 'set_variable', params: { name: 'x', value: '1' } } }],
      edges: [{ id: 'e', source: 't', sourceHandle: 'out', target: 'a' }]
    }
  end

  describe 'POST /automation_workflows' do
    it 'saves the graph and derives the triggers' do
      post base_url, headers: admin.create_new_auth_token, params: { automation_workflow: { name: 'Perdidos', active: true, graph: graph } }, as: :json

      expect(response).to have_http_status(:created)
      workflow = account.automation_workflows.last
      expect(workflow).to have_attributes(name: 'Perdidos', active: true, trigger_events: ['crm_deal_lost'])
      expect(workflow.graph['edges'].first).to include('source' => 't', 'target' => 'a')
      expect(response.parsed_body['webhook_url']).to end_with("/webhooks/automation_workflows/#{workflow.webhook_token}")
    end

    it 'refuses a graph with a cycle' do
      cyclic = graph.merge(edges: graph[:edges] + [{ id: 'back', source: 'a', target: 't' }])

      post base_url, headers: admin.create_new_auth_token, params: { automation_workflow: { name: 'Loop', graph: cyclic } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('cycles')
    end

    it 'refuses to activate a workflow without a trigger' do
      post base_url, headers: admin.create_new_auth_token, params: { automation_workflow: { name: 'Vazio', active: true, graph: { nodes: [], edges: [] } } },
                     as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'answers 422 for a graph whose parts are not objects' do
      broken = { nodes: [{ id: 't', type: 'trigger', data: 'x' }, { id: 's', type: 'switch', data: { field: 'deal.status', cases: ['a'] } }], edges: [] }

      post base_url, headers: admin.create_new_auth_token, params: { automation_workflow: { name: 'Quebrado', graph: broken } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'is not allowed for agents' do
      post base_url, headers: agent.create_new_auth_token, params: { automation_workflow: { name: 'X', graph: graph } }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /automation_workflows' do
    it 'lists the workflows of the account with their last run' do
      workflow = account.automation_workflows.create!(name: 'Perdidos', graph: graph.deep_stringify_keys, active: true)
      create(:account).automation_workflows.create!(name: 'De outra conta', graph: graph.deep_stringify_keys)
      workflow.runs.create!(account_id: account.id, trigger_event: 'manual', status: 'completed', started_at: Time.current)

      get base_url, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body.pluck('name')).to eq(['Perdidos'])
      expect(response.parsed_body.first['last_run']).to include('status' => 'completed')
    end
  end

  describe 'POST /automation_workflows/:id/run' do
    let!(:workflow) { account.automation_workflows.create!(name: 'Perdidos', graph: graph.deep_stringify_keys) }

    it 'starts a test run for a deal of the account' do
      pipeline = account.crm_pipelines.create!(name: 'Comercial')
      stage = account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0)
      deal = account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: create(:contact, account: account), name: 'Lead')

      post "#{base_url}/#{workflow.id}/run", headers: admin.create_new_auth_token, params: { deal_id: deal.id }, as: :json

      expect(response).to have_http_status(:accepted)
      expect(workflow.runs.last.context).to include('deal_id' => deal.id)
    end

    it 'ignores records of other accounts' do
      other_contact = create(:contact, account: create(:account))

      post "#{base_url}/#{workflow.id}/run", headers: admin.create_new_auth_token, params: { contact_id: other_contact.id }, as: :json

      expect(workflow.runs.last.context).to eq({})
    end
  end

  describe 'GET /automation_workflows/:id/runs' do
    it 'returns the latest runs with their trace' do
      workflow = account.automation_workflows.create!(name: 'Perdidos', graph: graph.deep_stringify_keys)
      workflow.runs.create!(account_id: account.id, trigger_event: 'manual', started_at: Time.current, trace: [{ 'node_id' => 't', 'status' => 'ok' }])

      get "#{base_url}/#{workflow.id}/runs", headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body.first).to include('trigger_event' => 'manual', 'trace' => [{ 'node_id' => 't', 'status' => 'ok' }])
    end
  end

  describe 'POST /webhooks/automation_workflows/:token' do
    let!(:workflow) do
      webhook_graph = graph.deep_stringify_keys
      webhook_graph['nodes'][0]['data']['event'] = 'webhook'
      account.automation_workflows.create!(name: 'Entrada', graph: webhook_graph, active: true)
    end

    it 'starts the workflow for the contact found by email, keeping the body as payload' do
      contact = create(:contact, account: account, email: 'maria@example.com')

      post "/webhooks/automation_workflows/#{workflow.webhook_token}", params: { email: 'Maria@example.com', plan: 'pro' }, as: :json

      expect(response).to have_http_status(:accepted)
      expect(workflow.runs.last.context).to include('contact_id' => contact.id, 'payload' => include('plan' => 'pro'))
    end

    it 'answers 404 for an unknown token or an inactive workflow' do
      post '/webhooks/automation_workflows/nope', params: {}, as: :json
      expect(response).to have_http_status(:not_found)

      workflow.update!(active: false)
      post "/webhooks/automation_workflows/#{workflow.webhook_token}", params: {}, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
