import { describe, expect, it } from 'vitest';
import { buildLookups } from './lookups';
import { caseLabel, summarizeNode } from './summaries';

const t = (key, params) => (params ? `${key}|${JSON.stringify(params)}` : key);

const lookups = buildLookups(
  {
    agents: [{ id: 7, name: 'Ana' }],
    teams: [{ id: 3, name: 'Suporte' }],
    pipelines: [
      {
        id: 1,
        name: 'Vendas',
        stages: [{ id: 10, name: 'Proposta', position: 1 }],
      },
    ],
    lostReasons: [{ id: 5, name: 'Sem orçamento', active: true }],
    dealFields: [{ key: 'origem', name: 'Origem', field_type: 'text' }],
  },
  t
);

const summary = (type, data) => summarizeNode({ type, data }, lookups);

describe('summarizeNode', () => {
  it('names the trigger event', () => {
    expect(summary('trigger', { event: 'crm_deal_lost' })).toEqual({
      title: 'AUTOMATION.WORKFLOWS.NODE_TYPES.TRIGGER',
      detail: 'AUTOMATION.WORKFLOWS.TRIGGERS.CRM_DEAL_LOST',
    });
  });

  it('writes the first condition and counts the others', () => {
    const { detail } = summary('condition', {
      conditions: [
        { field: 'deal.lost_reason_id', operator: 'equals', value: '5' },
        { field: 'deal.status', operator: 'equals', value: 'lost' },
      ],
    });
    expect(detail).toContain('AUTOMATION.WORKFLOWS.SUMMARY.AND_MORE');
    expect(detail).toContain('Sem orçamento');
    expect(detail).toContain('"n":1');
  });

  it('uses the custom field label', () => {
    const { detail } = summary('condition', {
      conditions: [
        { field: 'deal.custom.origem', operator: 'equals', value: 'Instagram' },
      ],
    });
    expect(detail).toBe(
      'Origem AUTOMATION.WORKFLOWS.OPERATORS.EQUALS Instagram'
    );
  });

  it('omits the value for operators that take none', () => {
    const { detail } = summary('condition', {
      conditions: [
        { field: 'contact.email', operator: 'is_present', value: '' },
      ],
    });
    expect(detail).toBe(
      'AUTOMATION.WORKFLOWS.FIELDS.CONTACT_EMAIL AUTOMATION.WORKFLOWS.OPERATORS.IS_PRESENT'
    );
  });

  it('summarizes a move as pipeline > stage', () => {
    expect(
      summary('action', {
        action: 'move_deal',
        params: { pipeline_id: 1, pipeline_stage_id: 10 },
      })
    ).toEqual({
      title: 'AUTOMATION.WORKFLOWS.ACTIONS.MOVE_DEAL',
      detail: 'Vendas › Proposta',
    });
  });

  it('adds the lost reason to the status summary', () => {
    expect(
      summary('action', {
        action: 'set_deal_status',
        params: { status: 'lost', lost_reason_id: 5 },
      }).detail
    ).toBe('AUTOMATION.WORKFLOWS.OPTIONS.DEAL_STATUS.LOST · Sem orçamento');
  });

  it('falls back to the id when the record is unknown and truncates long text', () => {
    expect(
      summary('action', { action: 'assign_agent', params: { agent_id: 99 } })
        .detail
    ).toBe('#99');
    const long = 'x'.repeat(200);
    const { detail } = summary('action', {
      action: 'send_message',
      params: { content: long },
    });
    expect(detail.length).toBe(60);
    expect(detail.endsWith('…')).toBe(true);
  });

  it('describes waits, switches and variables', () => {
    expect(summary('wait', { amount: 2, unit: 'days' }).detail).toContain(
      '"amount":2'
    );
    expect(
      summary('switch', { field: 'deal.lost_reason_id', cases: [{}, {}] })
        .detail
    ).toContain('"n":2');
    expect(
      summary('action', {
        action: 'set_variable',
        params: { name: 'a', value: 'b' },
      }).detail
    ).toBe('a = b');
  });
});

describe('caseLabel', () => {
  it('prefers the explicit label, then the resolved value', () => {
    const data = { field: 'deal.lost_reason_id' };
    expect(caseLabel(data, { value: '5', label: 'Preço' }, lookups)).toBe(
      'Preço'
    );
    expect(caseLabel(data, { value: '5' }, lookups)).toBe('Sem orçamento');
    expect(caseLabel(data, { value: '' }, lookups)).toBe(
      'AUTOMATION.WORKFLOWS.SWITCH.EMPTY_CASE'
    );
  });
});
