import { describe, expect, it } from 'vitest';
import { buildLookups } from './lookups';
import {
  FIELD_KINDS,
  buildCustomFields,
  fieldKindOf,
  fieldLabelKey,
  freePrefixOf,
  resolveField,
} from './fields';
import { valueOptionsFor } from './valueOptions';

const t = key => key;
const lookups = buildLookups(
  {
    agents: [{ id: 7, name: 'Ana' }],
    teams: [],
    inboxes: [{ id: 2, name: 'WhatsApp' }],
    pipelines: [
      {
        id: 1,
        name: 'Vendas',
        stages: [
          { id: 11, name: 'Fechamento', position: 2 },
          { id: 10, name: 'Proposta', position: 1 },
        ],
      },
    ],
    segments: [
      { id: 1, name: 'Ativo', active: true },
      { id: 2, name: 'Antigo', active: false },
    ],
    lostReasons: [
      { id: 5, name: 'Preço', active: true },
      { id: 6, name: 'Antigo motivo', active: false },
    ],
    dealFields: [
      {
        key: 'origem',
        name: 'Origem',
        field_type: 'select',
        options: ['Instagram', 'Site'],
      },
      { key: 'ticket', name: 'Ticket', field_type: 'currency' },
      { key: 'oculto', name: 'Oculto', field_type: 'text', active: false },
    ],
    contactAttributes: [
      {
        attribute_key: 'cidade',
        attribute_display_name: 'Cidade',
        attribute_values: [],
      },
    ],
  },
  t
);

describe('fields', () => {
  it('builds label keys from the field path', () => {
    expect(fieldLabelKey('deal.lost_reason_id')).toBe(
      'AUTOMATION.WORKFLOWS.FIELDS.DEAL_LOST_REASON_ID'
    );
    expect(fieldLabelKey('trigger.payload.')).toBe(
      'AUTOMATION.WORKFLOWS.FIELDS.TRIGGER_PAYLOAD'
    );
    expect(fieldLabelKey('change.status.to')).toBe(
      'AUTOMATION.WORKFLOWS.FIELDS.CHANGE_STATUS_TO'
    );
  });

  it('recognises the fields whose tail is typed by the user', () => {
    expect(freePrefixOf('trigger.payload.email')).toBe('trigger.payload.');
    expect(freePrefixOf('vars.')).toBe('vars.');
    expect(freePrefixOf('deal.name')).toBe('');
    expect(resolveField('trigger.payload.a.b').key).toBe('trigger.payload.');
  });

  it('turns custom fields and contact attributes into field entries', () => {
    const custom = buildCustomFields(
      [
        { key: 'origem', name: 'Origem', field_type: 'select', options: ['A'] },
        { key: 'oculto', name: 'Oculto', field_type: 'text', active: false },
      ],
      [
        {
          attribute_key: 'cidade',
          attribute_display_name: 'Cidade',
          attribute_values: [],
        },
      ]
    );
    expect(custom.map(item => item.key)).toEqual([
      'deal.custom.origem',
      'contact.custom.cidade',
    ]);
    expect(custom[0]).toMatchObject({
      kind: FIELD_KINDS.OPTIONS,
      choices: ['A'],
      label: 'Origem',
    });
    expect(custom[1].kind).toBe(FIELD_KINDS.TEXT);
  });

  it('knows the kind of each field', () => {
    const { customFields } = lookups;
    expect(fieldKindOf('deal.lost_reason_id', customFields)).toBe(
      FIELD_KINDS.LOST_REASON
    );
    expect(fieldKindOf('deal.value', customFields)).toBe(FIELD_KINDS.NUMBER);
    expect(fieldKindOf('deal.custom.ticket', customFields)).toBe(
      FIELD_KINDS.NUMBER
    );
    expect(fieldKindOf('unknown.thing', customFields)).toBe(FIELD_KINDS.TEXT);
  });
});

describe('valueOptionsFor', () => {
  it('offers only active lost reasons, with string values', () => {
    expect(valueOptionsFor('deal.lost_reason_id', lookups)).toEqual([
      { value: '5', label: 'Preço' },
    ]);
  });

  it('offers translated static options', () => {
    expect(
      valueOptionsFor('deal.status', lookups).map(item => item.value)
    ).toEqual(['open', 'won', 'lost']);
    expect(valueOptionsFor('deal.status', lookups)[0].label).toBe(
      'AUTOMATION.WORKFLOWS.OPTIONS.DEAL_STATUS.OPEN'
    );
  });

  it('offers the choices of a select custom field', () => {
    expect(valueOptionsFor('deal.custom.origem', lookups)).toEqual([
      { value: 'Instagram', label: 'Instagram' },
      { value: 'Site', label: 'Site' },
    ]);
  });

  it('is free text for plain fields', () => {
    expect(valueOptionsFor('contact.email', lookups)).toBeNull();
    expect(valueOptionsFor('deal.custom.ticket', lookups)).toBeNull();
  });
});

describe('buildLookups', () => {
  it('resolves names, keeps inactive records resolvable and falls back to #id', () => {
    expect(lookups.name('agent', 7)).toBe('Ana');
    expect(lookups.name('lost_reason', '6')).toBe('Antigo motivo');
    expect(lookups.name('segment', 2)).toBe('Antigo');
    expect(lookups.name('agent', 99)).toBe('#99');
    expect(lookups.name('agent', '')).toBe('');
  });

  it('lists the stages of a pipeline in order', () => {
    expect(lookups.stagesOf(1).map(item => item.label)).toEqual([
      'Proposta',
      'Fechamento',
    ]);
    expect(lookups.stagesOf('')).toEqual([]);
    expect(lookups.options('stage').map(item => item.label)).toContain(
      'Vendas › Proposta'
    );
  });

  it('hides inactive segments and deal fields from the pickers', () => {
    expect(lookups.options('segment').map(item => item.label)).toEqual([
      'Ativo',
    ]);
    expect(lookups.dealFields.map(item => item.value)).toEqual([
      'origem',
      'ticket',
    ]);
    expect(lookups.contactFields.map(item => item.value)).toEqual(['cidade']);
  });
});
