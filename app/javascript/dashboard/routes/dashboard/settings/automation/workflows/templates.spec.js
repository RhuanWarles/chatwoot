import { describe, expect, it } from 'vitest';
import { hasCycle, serializeGraph, validateGraph } from './graph';
import { WORKFLOW_TEMPLATES, lostReasonRoutingTemplate } from './templates';

const t = key => key;
const reasons = [
  { id: 1, name: 'Sem orçamento' },
  { id: 2, name: 'Concorrente' },
];

describe('lostReasonRoutingTemplate', () => {
  const { nodes, edges } = lostReasonRoutingTemplate(reasons);

  it('is trigger -> switch on the lost reason -> one move per reason', () => {
    expect(nodes.map(node => node.type)).toEqual([
      'trigger',
      'switch',
      'action',
      'action',
    ]);
    expect(nodes[0].data.event).toBe('crm_deal_lost');
    expect(nodes[1].data.field).toBe('deal.lost_reason_id');
    expect(nodes[1].data.cases.map(item => [item.value, item.label])).toEqual([
      ['1', 'Sem orçamento'],
      ['2', 'Concorrente'],
    ]);
    expect(nodes.slice(2).every(node => node.data.action === 'move_deal')).toBe(
      true
    );
  });

  it('connects every case handle to its own move', () => {
    const [, router, firstMove, secondMove] = nodes;
    const [firstCase, secondCase] = router.data.cases;
    expect(
      edges
        .filter(edge => edge.source === router.id)
        .map(edge => [edge.sourceHandle, edge.target])
    ).toEqual([
      [firstCase.id, firstMove.id],
      [secondCase.id, secondMove.id],
    ]);
    expect(hasCycle(nodes, edges)).toBe(false);
  });

  it('leaves the destination empty so the user must pick it', () => {
    const { byNode } = validateGraph(nodes, edges);
    expect(Object.keys(byNode)).toEqual([nodes[2].id, nodes[3].id]);
    expect(byNode[nodes[2].id].map(issue => issue.param)).toEqual([
      'pipeline_id',
      'pipeline_stage_id',
    ]);
  });

  it('works without any reason configured', () => {
    const empty = lostReasonRoutingTemplate([]);
    expect(empty.nodes.map(node => node.type)).toEqual(['trigger', 'switch']);
  });
});

describe('WORKFLOW_TEMPLATES', () => {
  it('builds graphs that serialize to the contract shape and have no loops', () => {
    WORKFLOW_TEMPLATES.forEach(template => {
      const graph = template.build({ t, lostReasons: reasons });
      const serialized = serializeGraph(graph.nodes, graph.edges);
      expect(serialized.nodes.length).toBeGreaterThan(1);
      expect(serialized.nodes.some(node => node.type === 'trigger')).toBe(true);
      expect(hasCycle(graph.nodes, graph.edges)).toBe(false);
    });
  });

  it('ships ready-to-run templates that only need the obvious inputs', () => {
    const byKey = Object.fromEntries(
      WORKFLOW_TEMPLATES.map(item => [item.key, item])
    );
    const welcome = byKey.welcome_message.build({ t });
    expect(validateGraph(welcome.nodes, welcome.edges).valid).toBe(true);
    const followUp = byKey.follow_up_task.build({ t });
    expect(validateGraph(followUp.nodes, followUp.edges).valid).toBe(true);
  });
});
