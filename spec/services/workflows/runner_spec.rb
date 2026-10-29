require 'rails_helper'

RSpec.describe Workflows::Runner do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:entry_stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:nurture_pipeline) { account.crm_pipelines.create!(name: 'Nutrição') }
  let!(:nurture_stage) { account.crm_pipeline_stages.create!(pipeline: nurture_pipeline, name: 'Reativar', position: 0) }
  let!(:price_reason) { account.crm_lost_reasons.create!(name: 'Preço') }
  let!(:silence_reason) { account.crm_lost_reasons.create!(name: 'Sem resposta') }
  let(:contact) { create(:contact, account: account) }
  let(:deal) do
    account.crm_deals.create!(pipeline: pipeline, pipeline_stage: entry_stage, contact: contact, name: 'Lead', status: 'lost',
                              lost_reason: price_reason)
  end
  let(:move_to_nurture) do
    { 'id' => 'move', 'type' => 'action', 'data' => { 'action' => 'move_deal', 'continue_on_error' => false,
                                                      'params' => { 'pipeline_id' => nurture_pipeline.id, 'pipeline_stage_id' => nurture_stage.id,
                                                                    'reopen' => true } } }
  end
  let(:trigger) { { 'id' => 'trigger', 'type' => 'trigger', 'data' => { 'event' => 'crm_deal_lost' } } }
  let(:route_by_reason) do
    { 'id' => 'route', 'type' => 'switch',
      'data' => { 'field' => 'deal.lost_reason_id', 'cases' => [{ 'id' => 'price', 'value' => price_reason.id.to_s }] } }
  end
  let(:graph) do
    {
      'nodes' => [trigger, route_by_reason, move_to_nurture],
      'edges' => [{ 'id' => 'e1', 'source' => 'trigger', 'target' => 'route' },
                  { 'id' => 'e2', 'source' => 'route', 'sourceHandle' => 'price', 'target' => 'move' }]
    }
  end
  let(:workflow) { account.automation_workflows.create!(name: 'Roteamento por motivo', graph: graph, active: true) }

  def start(context = { 'deal_id' => deal.id, 'contact_id' => contact.id })
    run = workflow.runs.create!(account_id: account.id, trigger_event: 'crm_deal_lost', started_at: Time.current, context: context,
                                pending: [{ 'node_id' => 'trigger' }])
    described_class.new(run).perform
    run.reload
  end

  it 'moves a lost deal to the pipeline chosen for its reason' do
    run = start

    expect(run.status).to eq('completed')
    expect(deal.reload).to have_attributes(pipeline_id: nurture_pipeline.id, pipeline_stage_id: nurture_stage.id, status: 'open', lost_reason_id: nil)
    expect(run.trace.pluck('node_id')).to eq(%w[trigger route move])
  end

  it 'follows the default branch when no case matches' do
    deal.update!(lost_reason: silence_reason)

    run = start

    expect(run.status).to eq('completed')
    expect(deal.reload.pipeline_id).to eq(pipeline.id)
    expect(run.trace.pluck('node_id')).to eq(%w[trigger route])
  end

  it 'follows the true or false branch of a condition' do
    condition = { 'id' => 'if', 'type' => 'condition',
                  'data' => { 'match' => 'all', 'conditions' => [{ 'field' => 'deal.value', 'operator' => 'gt', 'value' => '1000' }] } }
    workflow.update!(graph: { 'nodes' => [trigger, condition, move_to_nurture],
                              'edges' => [{ 'id' => 'e1', 'source' => 'trigger', 'target' => 'if' },
                                          { 'id' => 'e2', 'source' => 'if', 'sourceHandle' => 'false', 'target' => 'move' }] })
    deal.update!(value: 500)

    run = start

    expect(run.trace.pluck('node_id')).to eq(%w[trigger if move])
  end

  it 'fails the run and stops when an action fails' do
    move_to_nurture['data']['params']['pipeline_stage_id'] = entry_stage.id

    run = start

    expect(run.status).to eq('failed')
    expect(run.trace.last).to include('node_id' => 'move', 'status' => 'error')
  end

  it 'keeps going after a failed action that is allowed to continue' do
    followup = { 'id' => 'note', 'type' => 'action', 'data' => { 'action' => 'set_variable', 'params' => { 'name' => 'done', 'value' => 'yes' } } }
    move_to_nurture['data'].merge!('continue_on_error' => true, 'params' => { 'pipeline_id' => 999_999, 'pipeline_stage_id' => 999_999 })
    workflow.update!(graph: { 'nodes' => [trigger, move_to_nurture, followup],
                              'edges' => [{ 'id' => 'e1', 'source' => 'trigger', 'target' => 'move' },
                                          { 'id' => 'e2', 'source' => 'move', 'target' => 'note' }] })

    run = start

    expect(run.status).to eq('completed')
    expect(run.context['vars']).to eq('done' => 'yes')
  end

  it 'waits and resumes after the delay' do
    wait = { 'id' => 'wait', 'type' => 'wait', 'data' => { 'amount' => 2, 'unit' => 'hours' } }
    workflow.update!(graph: { 'nodes' => [trigger, wait, move_to_nurture],
                              'edges' => [{ 'id' => 'e1', 'source' => 'trigger', 'target' => 'wait' },
                                          { 'id' => 'e2', 'source' => 'wait', 'target' => 'move' }] })

    run = start

    expect(run.status).to eq('waiting')
    expect(run.resume_at).to be_within(1.minute).of(2.hours.from_now)
    expect(deal.reload.pipeline_id).to eq(pipeline.id)

    travel_to(3.hours.from_now) { described_class.new(run).perform }

    expect(run.reload.status).to eq('completed')
    expect(deal.reload.pipeline_id).to eq(nurture_pipeline.id)
  end

  it 'runs a node once even when two branches join into it' do
    note = { 'id' => 'note', 'type' => 'action', 'data' => { 'action' => 'set_variable', 'params' => { 'name' => 'count', 'value' => 'x' } } }
    both = { 'id' => 'both', 'type' => 'condition', 'data' => { 'match' => 'all', 'conditions' => [] } }
    workflow.update!(graph: { 'nodes' => [trigger, both, note],
                              'edges' => [{ 'id' => 'e1', 'source' => 'trigger', 'target' => 'both' },
                                          { 'id' => 'e2', 'source' => 'both', 'sourceHandle' => 'true', 'target' => 'note' },
                                          { 'id' => 'e3', 'source' => 'trigger', 'target' => 'note' }] })

    expect(start.trace.pluck('node_id')).to eq(%w[trigger both note])
  end

  it 'encodes what customers wrote in the url and the body of a request' do
    deal.update!(name: 'A&b=1/../x "q"')
    request = { 'id' => 'req', 'type' => 'action',
                'data' => { 'action' => 'http_request',
                            'params' => { 'method' => 'POST', 'url' => 'https://example.com/leads/{{deal.name}}', 'body' => '{"name":"{{deal.name}}"}' } } }
    workflow.update!(graph: { 'nodes' => [trigger, request], 'edges' => [{ 'id' => 'e1', 'source' => 'trigger', 'target' => 'req' }] })
    allow(SafeFetch).to receive(:fetch)

    start

    expect(SafeFetch).to have_received(:fetch).with(
      'https://example.com/leads/A%26b%3D1%2F..%2Fx%20%22q%22', hash_including(body: '{"name":"A&b=1/../x \\"q\\""}')
    )
  end

  it 'renders template variables in params' do
    note = { 'id' => 'note', 'type' => 'action',
             'data' => { 'action' => 'set_variable', 'params' => { 'name' => 'why', 'value' => 'Perdido por {{deal.lost_reason}} ({{deal.name}})' } } }
    workflow.update!(graph: { 'nodes' => [trigger, note], 'edges' => [{ 'id' => 'e1', 'source' => 'trigger', 'target' => 'note' }] })

    expect(start.context['vars']).to eq('why' => 'Perdido por Preço (Lead)')
  end
end
