import { describe, expect, it } from 'vitest';
import {
  connectionError,
  createEdge,
  createNode,
  defaultNodeData,
  findFreePosition,
  graphSignature,
  hasCycle,
  hydrateGraph,
  outputHandles,
  serializeGraph,
  triggerEventsOf,
  validateGraph,
  wouldCreateCycle,
} from './graph';

const node = (id, type, data = {}, position = { x: 0, y: 0 }) => ({
  id,
  type,
  position,
  data: { ...defaultNodeData(type, data), ...data },
});
const edge = (source, target, sourceHandle = 'out') => ({
  id: `${source}-${target}-${sourceHandle}`,
  source,
  sourceHandle,
  target,
});
const sendMessage = (id, content = 'Hi') =>
  node(id, 'action', { action: 'send_message', params: { content } });

const codes = validation => validation.issues.map(issue => issue.code);

describe('createNode / defaultNodeData', () => {
  it('builds a trigger with the requested event', () => {
    const created = createNode('trigger', {
      preset: { event: 'crm_deal_lost' },
    });
    expect(created.type).toBe('trigger');
    expect(created.data).toEqual({ event: 'crm_deal_lost' });
    expect(created.id).toMatch(/^trigger_/);
  });

  it('starts an action with the defaults of its definition', () => {
    const created = createNode('action', { preset: { action: 'move_deal' } });
    expect(created.data).toEqual({
      action: 'move_deal',
      params: { pipeline_id: '', pipeline_stage_id: '', reopen: true },
      continue_on_error: false,
    });
  });

  it('gives every node a unique id', () => {
    const ids = Array.from({ length: 50 }, () => createNode('wait').id);
    expect(new Set(ids).size).toBe(50);
  });
});

describe('outputHandles', () => {
  it('has yes and no for a condition', () => {
    expect(outputHandles(node('c', 'condition')).map(item => item.id)).toEqual([
      'true',
      'false',
    ]);
  });

  it('has one handle per switch case plus the default one', () => {
    const router = node('s', 'switch', {
      field: 'deal.status',
      cases: [
        { id: 'a', value: 'won' },
        { id: 'b', value: 'lost' },
      ],
    });
    expect(outputHandles(router).map(item => item.id)).toEqual([
      'a',
      'b',
      'default',
    ]);
  });

  it('has a single out handle for the other blocks', () => {
    expect(outputHandles(node('w', 'wait')).map(item => item.id)).toEqual([
      'out',
    ]);
  });
});

describe('cycle detection', () => {
  const chain = [edge('a', 'b'), edge('b', 'c')];

  it('rejects a connection that closes a loop', () => {
    expect(wouldCreateCycle(chain, 'c', 'a')).toBe(true);
    expect(wouldCreateCycle(chain, 'a', 'c')).toBe(false);
    expect(wouldCreateCycle(chain, 'b', 'b')).toBe(true);
  });

  it('tells whether a whole graph has a cycle', () => {
    const nodes = ['a', 'b', 'c'].map(id => node(id, 'wait'));
    expect(hasCycle(nodes, chain)).toBe(false);
    expect(hasCycle(nodes, [...chain, edge('c', 'a')])).toBe(true);
  });
});

describe('connectionError', () => {
  const nodes = [
    node('t', 'trigger'),
    node('c', 'condition', {}),
    sendMessage('m'),
  ];
  const edges = [edge('t', 'c'), edge('c', 'm', 'true')];

  it('allows a valid connection', () => {
    expect(
      connectionError(nodes, edges, {
        source: 'c',
        sourceHandle: 'false',
        target: 'm',
      })
    ).toBe('');
  });

  it('refuses self loops, trigger inputs, unknown handles, duplicates and cycles', () => {
    expect(connectionError(nodes, edges, { source: 'm', target: 'm' })).toBe(
      'SELF_LOOP'
    );
    expect(connectionError(nodes, edges, { source: 'm', target: 't' })).toBe(
      'TRIGGER_INPUT'
    );
    expect(
      connectionError(nodes, edges, {
        source: 'c',
        sourceHandle: 'maybe',
        target: 'm',
      })
    ).toBe('UNKNOWN_HANDLE');
    expect(
      connectionError(nodes, edges, {
        source: 'c',
        sourceHandle: 'true',
        target: 'm',
      })
    ).toBe('DUPLICATE');
    expect(connectionError(nodes, edges, { source: 'm', target: 'c' })).toBe(
      'CYCLE'
    );
    expect(connectionError(nodes, edges, { source: 'x', target: 'c' })).toBe(
      'MISSING_NODE'
    );
  });

  it('creates edges that default to the out handle', () => {
    expect(createEdge({ source: 'a', target: 'b' })).toMatchObject({
      source: 'a',
      sourceHandle: 'out',
      target: 'b',
    });
  });
});

describe('serializeGraph / hydrateGraph', () => {
  it('keeps only the contract fields and rounds positions', () => {
    const nodes = [
      {
        ...node('t', 'trigger', {}, { x: 10.6, y: 20.2 }),
        selected: true,
        dimensions: { width: 1 },
      },
    ];
    const edges = [
      { ...edge('t', 't2', 'out'), markerEnd: 'arrowclosed', selected: true },
    ];
    const graph = serializeGraph(nodes, edges);
    expect(graph.nodes).toEqual([
      {
        id: 't',
        type: 'trigger',
        position: { x: 11, y: 20 },
        data: { event: 'conversation_created' },
      },
    ]);
    expect(graph.edges).toEqual([
      { id: 't-t2-out', source: 't', sourceHandle: 'out', target: 't2' },
    ]);
  });

  it('hydrates stored graphs and drops edges pointing to missing nodes', () => {
    const { nodes, edges } = hydrateGraph({
      nodes: [
        {
          id: 'a',
          type: 'trigger',
          position: { x: 1, y: 2 },
          data: { event: 'crm_deal_won' },
        },
        {
          id: 'b',
          type: 'action',
          position: { x: 3, y: 4 },
          data: { action: 'move_deal', params: { pipeline_id: 2 } },
        },
      ],
      edges: [
        { id: 'e1', source: 'a', target: 'b' },
        { id: 'e2', source: 'a', target: 'gone' },
      ],
    });
    expect(edges).toEqual([
      {
        id: 'e1',
        source: 'a',
        sourceHandle: 'out',
        target: 'b',
        markerEnd: 'arrowclosed',
      },
    ]);
    // Params missing from the stored node are filled with the action defaults.
    expect(nodes[1].data.params).toEqual({
      pipeline_id: 2,
      pipeline_stage_id: '',
      reopen: true,
    });
  });

  it('round-trips without changes', () => {
    const graph = {
      nodes: [
        {
          id: 'a',
          type: 'trigger',
          position: { x: 0, y: 0 },
          data: { event: 'webhook' },
        },
        {
          id: 'b',
          type: 'wait',
          position: { x: 300, y: 0 },
          data: { amount: 2, unit: 'days' },
        },
      ],
      edges: [{ id: 'e', source: 'a', sourceHandle: 'out', target: 'b' }],
    };
    const { nodes, edges } = hydrateGraph(graph);
    expect(serializeGraph(nodes, edges)).toEqual(graph);
  });

  it('changes the signature when anything is edited', () => {
    const nodes = [node('t', 'trigger')];
    const base = {
      name: 'x',
      description: '',
      active: false,
      nodes,
      edges: [],
    };
    expect(graphSignature(base)).toBe(graphSignature({ ...base }));
    expect(graphSignature({ ...base, name: 'y' })).not.toBe(
      graphSignature(base)
    );
    expect(graphSignature({ ...base, active: true })).not.toBe(
      graphSignature(base)
    );
  });
});

describe('triggerEventsOf / findFreePosition', () => {
  it('lists the distinct trigger events', () => {
    const nodes = [
      node('a', 'trigger', { event: 'webhook' }),
      node('b', 'trigger', { event: 'webhook' }),
      node('c', 'trigger', { event: 'crm_deal_lost' }),
      node('d', 'wait'),
    ];
    expect(triggerEventsOf(nodes)).toEqual(['webhook', 'crm_deal_lost']);
  });

  it('nudges a new node away from the ones already there', () => {
    const nodes = [node('a', 'wait', {}, { x: 100, y: 100 })];
    expect(findFreePosition(nodes, { x: 500, y: 500 })).toEqual({
      x: 500,
      y: 500,
    });
    const moved = findFreePosition(nodes, { x: 100, y: 100 });
    expect(moved).not.toEqual({ x: 100, y: 100 });
  });
});

describe('validateGraph', () => {
  it('is valid for trigger -> filled action', () => {
    const result = validateGraph(
      [node('t', 'trigger'), sendMessage('m')],
      [edge('t', 'm')]
    );
    expect(result.valid).toBe(true);
  });

  it('requires a trigger and flags unreachable blocks', () => {
    expect(codes(validateGraph([sendMessage('m')], []))).toEqual([
      'NO_TRIGGER',
      'UNREACHABLE',
    ]);
  });

  it('flags a loop', () => {
    const nodes = [node('t', 'trigger'), sendMessage('a'), sendMessage('b')];
    const result = validateGraph(nodes, [
      edge('t', 'a'),
      edge('a', 'b'),
      edge('b', 'a'),
    ]);
    expect(codes(result)).toContain('CYCLE');
  });

  it('reports the missing params of an action per node', () => {
    const nodes = [
      node('t', 'trigger'),
      node('m', 'action', { action: 'move_deal' }),
    ];
    const result = validateGraph(nodes, [edge('t', 'm')]);
    expect(result.byNode.m).toEqual([
      { nodeId: 'm', code: 'PARAM_REQUIRED', param: 'pipeline_id' },
      { nodeId: 'm', code: 'PARAM_REQUIRED', param: 'pipeline_stage_id' },
    ]);
  });

  it('only requires the params that are visible', () => {
    const won = node('w', 'action', {
      action: 'set_deal_status',
      params: { status: 'won' },
    });
    const owner = node('o', 'action', {
      action: 'assign_deal_owner',
      params: { mode: 'random', user_id: '', user_ids: [] },
    });
    const result = validateGraph(
      [node('t', 'trigger'), won, owner],
      [edge('t', 'w'), edge('w', 'o')]
    );
    expect(result.byNode.w).toBeUndefined();
    expect(result.byNode.o).toEqual([
      { nodeId: 'o', code: 'PARAM_REQUIRED', param: 'user_ids' },
    ]);
  });

  it('requires at least one field for update_deal and a key per field entry', () => {
    const update = node('u', 'action', { action: 'update_deal', params: {} });
    const fields = node('f', 'action', {
      action: 'set_deal_field',
      params: { fields: [{ key: '', value: 'x' }] },
    });
    const result = validateGraph(
      [node('t', 'trigger'), update, fields],
      [edge('t', 'u'), edge('u', 'f')]
    );
    expect(codes({ issues: result.byNode.u })).toEqual(['AT_LEAST_ONE']);
    expect(result.byNode.f).toEqual([
      { nodeId: 'f', code: 'PARAM_REQUIRED', param: 'fields' },
    ]);
  });

  it('validates wait, condition and switch blocks', () => {
    const wait = node('w', 'wait', { amount: 0, unit: 'days' });
    const condition = node('c', 'condition', {
      conditions: [
        { field: 'trigger.payload.', operator: 'equals', value: 'x' },
      ],
    });
    const router = node('s', 'switch', {
      field: 'deal.status',
      cases: [{ id: 'a', value: '' }],
    });
    const result = validateGraph(
      [node('t', 'trigger'), wait, condition, router],
      [edge('t', 'w'), edge('w', 'c'), edge('c', 's', 'true')]
    );
    expect(result.byNode.w.map(item => item.code)).toEqual(['WAIT_AMOUNT']);
    // A bare webhook prefix is not a complete field.
    expect(result.byNode.c.map(item => item.code)).toEqual([
      'CONDITION_INCOMPLETE',
    ]);
    expect(result.byNode.s.map(item => item.code)).toEqual([
      'SWITCH_CASE_VALUE',
    ]);
  });

  it('does not require a value for is_present', () => {
    const condition = node('c', 'condition', {
      conditions: [
        { field: 'contact.email', operator: 'is_present', value: '' },
      ],
    });
    const result = validateGraph(
      [node('t', 'trigger'), condition],
      [edge('t', 'c')]
    );
    expect(result.valid).toBe(true);
  });

  it('limits the size of a workflow', () => {
    const nodes = [node('t', 'trigger')];
    const edges = [];
    for (let i = 0; i < 100; i += 1) {
      nodes.push(sendMessage(`m${i}`));
      edges.push(edge('t', `m${i}`));
    }
    expect(codes(validateGraph(nodes, edges))).toContain('TOO_MANY_NODES');
  });
});
