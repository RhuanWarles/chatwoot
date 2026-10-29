require 'rails_helper'

RSpec.describe Workflows::Graph do
  let(:trigger) { { 'id' => 't', 'type' => 'trigger', 'data' => { 'event' => 'crm_deal_lost' } } }
  let(:action) { { 'id' => 'a', 'type' => 'action', 'data' => { 'action' => 'move_deal', 'params' => {} } } }
  let(:edge) { { 'id' => 'e', 'source' => 't', 'sourceHandle' => 'out', 'target' => 'a' } }

  def errors_for(nodes, edges)
    described_class.new('nodes' => nodes, 'edges' => edges).errors
  end

  it 'accepts a connected graph' do
    expect(errors_for([trigger, action], [edge])).to be_empty
  end

  it 'rejects unknown trigger events and actions' do
    graph = [trigger.merge('data' => { 'event' => 'nope' }), action.merge('data' => { 'action' => 'nope' })]

    expect(errors_for(graph, [])).to include('unknown trigger event "nope"', 'unknown action "nope"')
  end

  it 'rejects edges to missing nodes and self loops' do
    expect(errors_for([trigger], [edge])).to include('edges must connect existing nodes')
    expect(errors_for([trigger], [edge.merge('target' => 't')])).to include('edges must connect existing nodes')
  end

  it 'rejects cycles' do
    other = action.merge('id' => 'b')
    edges = [edge, { 'id' => 'e2', 'source' => 'a', 'target' => 'b' }, { 'id' => 'e3', 'source' => 'b', 'target' => 'a' }]

    expect(errors_for([trigger, action, other], edges)).to include('graph must not contain cycles')
  end

  it 'rejects repeated node ids' do
    expect(errors_for([trigger, trigger], [])).to include('node ids must be present and unique')
  end

  it 'checks conditions, switches and waits' do
    nodes = [
      { 'id' => 'c', 'type' => 'condition', 'data' => { 'match' => 'all', 'conditions' => [{ 'field' => 'deal.status', 'operator' => 'nope' }] } },
      { 'id' => 's', 'type' => 'switch', 'data' => { 'field' => 'deal.lost_reason_id', 'cases' => [{ 'id' => 'x' }, { 'id' => 'x' }] } },
      { 'id' => 'w', 'type' => 'wait', 'data' => { 'amount' => 0, 'unit' => 'hours' } }
    ]

    expect(errors_for(nodes, [])).to include('unknown operator "nope"', 'switch case ids must be present and unique',
                                             'wait needs a positive amount and a unit (minutes, hours or days)')
  end

  it 'finds the next nodes of a handle, defaulting to out' do
    graph = described_class.new('nodes' => [trigger, action], 'edges' => [edge.except('sourceHandle')])

    expect(graph.targets('t', 'out')).to eq(['a'])
    expect(graph.targets('t', 'true')).to be_empty
  end
end
