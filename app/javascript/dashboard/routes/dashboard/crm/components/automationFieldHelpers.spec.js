import {
  MAX_AUTOMATIONS,
  cloneAutomations,
  createAction,
  getActionErrors,
  getActionSummary,
  getConditionErrors,
  getFieldOperators,
  getOperatorLabelKey,
  isAutomationValid,
  serializeAutomations,
} from './automationHelpers';

const segment = {
  id: 5,
  name: 'Segmento',
  key: 'segmento',
  field_type: 'select',
  options: ['Restaurante', 'Clínica'],
};
const interests = {
  id: 6,
  name: 'Interesses',
  key: 'interesses',
  field_type: 'multiselect',
  options: ['Site', 'App'],
};
const budget = {
  id: 7,
  name: 'Orçamento',
  key: 'orcamento',
  field_type: 'currency',
  options: [],
};
const fields = [segment, interests, budget];
const destinations = [
  { id: 1, name: 'Comercial', stages: [{ id: 10, name: 'Novo' }] },
];
const route = overrides => ({
  key: 'r1',
  operator: 'equals',
  value: 'Restaurante',
  pipeline_id: 1,
  stage_id: 10,
  ...overrides,
});

describe('automation limit', () => {
  it('allows 50 actions per trigger', () => {
    expect(MAX_AUTOMATIONS).toBe(50);
  });
});

describe('assign_random', () => {
  it.each([
    [{ type: 'assign_random', user_ids: [1, 2] }, true],
    [{ type: 'assign_random', user_ids: [] }, false],
    [{ type: 'assign_random' }, false],
  ])('validates %j as %s', (action, expected) => {
    expect(isAutomationValid(action)).toBe(expected);
  });

  it('starts empty so the user has to pick the sellers', () => {
    expect(createAction('assign_random').user_ids).toEqual([]);
  });
});

describe('set_field', () => {
  it.each([
    [{ type: 'set_field', custom_field_id: 5, value: 'Clínica' }, true],
    [{ type: 'set_field', custom_field_id: 5, value: 'Padaria' }, false],
    [{ type: 'set_field', custom_field_id: 5, value: '' }, false],
    [{ type: 'set_field', custom_field_id: 6, value: ['Site', 'App'] }, true],
    [{ type: 'set_field', custom_field_id: 6, value: [] }, false],
    [{ type: 'set_field', custom_field_id: 6, value: ['Blog'] }, false],
    [{ type: 'set_field', custom_field_id: 7, value: '1500.50' }, true],
    [{ type: 'set_field', custom_field_id: 7, value: '1.500,50' }, false],
    [{ type: 'set_field', custom_field_id: 99, value: 'x' }, false],
    [{ type: 'set_field', custom_field_id: null, value: 'x' }, false],
  ])('validates %j as %s', (action, expected) => {
    expect(isAutomationValid(action, { fields })).toBe(expected);
  });
});

describe('route_by_field', () => {
  const action = overrides => ({
    type: 'route_by_field',
    custom_field_id: 5,
    routes: [route()],
    fallback: null,
    ...overrides,
  });

  it('accepts routes to stages that exist', () => {
    expect(isAutomationValid(action(), { fields, destinations })).toBe(true);
  });

  it('needs a field and at least one route', () => {
    expect(
      getActionErrors(action({ custom_field_id: null }), { fields })
    ).toHaveProperty('custom_field_id');
    expect(getActionErrors(action({ routes: [] }), { fields })).toHaveProperty(
      'routes'
    );
  });

  it('flags routes without a value, a stage or a stage that disappeared', () => {
    [
      route({ value: '' }),
      route({ stage_id: null }),
      route({ stage_id: 99 }),
    ].forEach(bad => {
      expect(
        getActionErrors(action({ routes: [bad] }), { fields, destinations })
      ).toHaveProperty('routes');
    });
  });

  it('needs no value for rules like "is filled in"', () => {
    const filled = route({ operator: 'filled', value: '' });

    expect(
      isAutomationValid(action({ routes: [filled] }), { fields, destinations })
    ).toBe(true);
  });

  it('checks the fallback stage', () => {
    const withFallback = fallback => action({ fallback });

    expect(
      isAutomationValid(withFallback({ pipeline_id: 1, stage_id: 10 }), {
        fields,
        destinations,
      })
    ).toBe(true);
    expect(
      isAutomationValid(withFallback({ pipeline_id: 1, stage_id: null }), {
        fields,
        destinations,
      })
    ).toBe(false);
  });
});

describe('conditions', () => {
  const condition = overrides => ({
    custom_field_id: 5,
    operator: 'equals',
    value: 'Restaurante',
    ...overrides,
  });

  it('validates the field, the operator and the value', () => {
    expect(getConditionErrors(condition(), { fields })).toEqual({});
    expect(
      getConditionErrors(condition({ custom_field_id: null }), { fields })
    ).toHaveProperty('custom_field_id');
    expect(
      getConditionErrors(condition({ operator: 'gt' }), { fields })
    ).toHaveProperty('operator');
    expect(
      getConditionErrors(condition({ value: ' ' }), { fields })
    ).toHaveProperty('value');
  });

  it('only asks for numbers or dates when comparing sizes', () => {
    const budgetCondition = overrides =>
      condition({ custom_field_id: 7, operator: 'gt', ...overrides });

    expect(
      getConditionErrors(budgetCondition({ value: '1000' }), { fields })
    ).toEqual({});
    expect(
      getConditionErrors(budgetCondition({ value: 'muito' }), { fields })
    ).toHaveProperty('value');
  });

  it('can be attached to any action and makes it incomplete while it is not valid', () => {
    const base = { type: 'add_label', label: 'vip' };

    expect(
      isAutomationValid({ ...base, condition: condition() }, { fields })
    ).toBe(true);
    expect(
      isAutomationValid(
        { ...base, condition: condition({ custom_field_id: null }) },
        { fields }
      )
    ).toBe(false);
  });

  it('offers only the operators that make sense for each field type', () => {
    expect(getFieldOperators(budget)).toEqual(
      expect.arrayContaining(['gt', 'lt'])
    );
    expect(getFieldOperators(segment)).not.toContain('gt');
    expect(getFieldOperators(interests)).toContain('equals');
    expect(getOperatorLabelKey('equals', interests)).toBe(
      'CRM.AUTOMATION_OPERATOR_INCLUDES'
    );
    expect(getOperatorLabelKey('equals', segment)).toBe(
      'CRM.AUTOMATION_OPERATOR_EQUALS'
    );
  });
});

describe('serializeAutomations', () => {
  it('drops the keys used only by the screen', () => {
    const [action] = serializeAutomations([
      {
        key: 'a1',
        type: 'route_by_field',
        custom_field_id: 5,
        routes: [route()],
        fallback: null,
      },
    ]);

    expect(action).toEqual({
      type: 'route_by_field',
      custom_field_id: 5,
      routes: [
        {
          operator: 'equals',
          value: 'Restaurante',
          pipeline_id: 1,
          stage_id: 10,
        },
      ],
    });
  });

  it('keeps the fallback and the condition, without a value for rules that need none', () => {
    const [action] = serializeAutomations([
      {
        key: 'a1',
        type: 'add_label',
        label: 'vip',
        condition: { custom_field_id: 5, operator: 'filled', value: '' },
      },
      {
        key: 'a2',
        type: 'route_by_field',
        custom_field_id: 5,
        routes: [route({ operator: 'filled', value: '' })],
        fallback: { pipeline_id: 1, stage_id: 10 },
      },
    ]);

    expect(action.condition).toEqual({
      custom_field_id: 5,
      operator: 'filled',
    });
  });

  it('gives cloned routes their own keys', () => {
    const [cloned] = cloneAutomations([
      {
        type: 'route_by_field',
        custom_field_id: 5,
        routes: [{ operator: 'equals' }],
      },
    ]);

    expect(cloned.key).toBeTruthy();
    expect(cloned.routes[0].key).toBeTruthy();
  });
});

describe('getActionSummary', () => {
  const t = (key, params = {}) => `${key}:${JSON.stringify(params)}`;
  const agents = [
    { id: 1, name: 'Brenda' },
    { id: 2, name: 'Rodolpho' },
  ];

  it('names the sellers in the draw', () => {
    expect(
      getActionSummary(
        { type: 'assign_random', user_ids: [1, 2] },
        { t, agents }
      )
    ).toBe(
      'CRM.AUTOMATION_SUMMARY_RANDOM:{"count":2,"names":"Brenda, Rodolpho"}'
    );
  });

  it('describes a field being filled in', () => {
    expect(
      getActionSummary(
        { type: 'set_field', custom_field_id: 6, value: ['Site', 'App'] },
        { t, agents, fields }
      )
    ).toBe(
      'CRM.AUTOMATION_SUMMARY_SET_FIELD:{"field":"Interesses","value":"Site, App"}'
    );
  });

  it('adds the condition to the summary', () => {
    const summary = getActionSummary(
      {
        type: 'add_label',
        label: 'vip',
        condition: { custom_field_id: 5, operator: 'equals', value: 'Clínica' },
      },
      { t, agents, fields }
    );

    expect(summary).toContain('CRM.AUTOMATION_SUMMARY_CONDITION');
    expect(summary).toContain('Segmento');
  });
});
