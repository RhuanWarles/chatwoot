import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import { createI18n } from 'vue-i18n';
import { describe, expect, it, vi } from 'vitest';
import messages from 'dashboard/i18n/locale/en/automation.json';
import { buildLookups } from '../../lookups';
import ActionEditor from './ActionEditor.vue';
import ConditionsEditor from './ConditionsEditor.vue';
import NodeInspector from './NodeInspector.vue';
import SwitchEditor from './SwitchEditor.vue';

vi.mock('../../useWorkflowLookups', () => ({
  useWorkflowLookups: () => ({
    lookups: ref(
      buildLookups({
        agents: [{ id: 7, name: 'Ana' }],
        pipelines: [
          {
            id: 1,
            name: 'Vendas',
            stages: [{ id: 10, name: 'Proposta', position: 1 }],
          },
        ],
        lostReasons: [
          { id: 5, name: 'Sem orçamento', active: true },
          { id: 6, name: 'Concorrente', active: true },
          { id: 7, name: 'Desativado', active: false },
        ],
      })
    ),
  }),
}));

const mountWith = (component, props) =>
  mount(component, {
    props,
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'en',
          messages: { en: messages },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
    },
  });

const lastEmit = wrapper => wrapper.emitted('update:modelValue').at(-1)[0];

describe('ConditionsEditor', () => {
  const modelValue = {
    match: 'all',
    conditions: [{ field: 'deal.status', operator: 'equals', value: 'lost' }],
  };

  it('adds an empty condition', async () => {
    const wrapper = mountWith(ConditionsEditor, { modelValue });
    const addButton = wrapper
      .findAll('button')
      .find(button => button.text().includes('Add condition'));
    await addButton.trigger('click');

    expect(lastEmit(wrapper).conditions).toEqual([
      modelValue.conditions[0],
      { field: '', operator: 'equals', value: '' },
    ]);
  });

  it('turns the value into a list for "is one of" and clears it for "is filled"', async () => {
    const wrapper = mountWith(ConditionsEditor, { modelValue });
    const operatorSelect = wrapper.findAll('select').at(1);

    await operatorSelect.setValue('in');
    expect(lastEmit(wrapper).conditions[0]).toMatchObject({
      operator: 'in',
      value: ['lost'],
    });

    await operatorSelect.setValue('is_present');
    expect(lastEmit(wrapper).conditions[0]).toMatchObject({
      operator: 'is_present',
      value: '',
    });
  });
});

describe('SwitchEditor', () => {
  it('adds one case per active lost reason, without duplicating existing ones', async () => {
    const wrapper = mountWith(SwitchEditor, {
      modelValue: {
        field: 'deal.lost_reason_id',
        cases: [{ id: 'c1', value: '5', label: 'Sem orçamento' }],
      },
    });
    const button = wrapper
      .findAll('button')
      .find(item => item.text().includes('one case per lost reason'));
    await button.trigger('click');

    const { cases } = lastEmit(wrapper);
    expect(cases.map(item => [item.value, item.label])).toEqual([
      ['5', 'Sem orçamento'],
      ['6', 'Concorrente'],
    ]);
    expect(cases[1].id).toMatch(/^case_/);
  });

  it('does not offer a case per option for free text fields', () => {
    const wrapper = mountWith(SwitchEditor, {
      modelValue: { field: 'contact.email', cases: [] },
    });
    expect(wrapper.text()).not.toContain('one case per');
  });

  it('drops the cases when the field changes', async () => {
    const wrapper = mountWith(SwitchEditor, {
      modelValue: { field: 'deal.status', cases: [{ id: 'c1', value: 'won' }] },
    });
    await wrapper
      .findComponent({ name: 'FieldPicker' })
      .vm.$emit('update:modelValue', 'deal.name');

    expect(lastEmit(wrapper)).toEqual({ field: 'deal.name', cases: [] });
  });
});

describe('ActionEditor', () => {
  it('resets the params when the action changes', async () => {
    const wrapper = mountWith(ActionEditor, {
      modelValue: {
        action: 'send_message',
        params: { content: 'Hi' },
        continue_on_error: false,
      },
    });
    await wrapper.find('select').setValue('move_deal');

    expect(lastEmit(wrapper)).toEqual({
      action: 'move_deal',
      params: { pipeline_id: '', pipeline_stage_id: '', reopen: true },
      continue_on_error: false,
    });
  });

  it('only shows the lost reason params when the status is lost', async () => {
    const wrapper = mountWith(ActionEditor, {
      modelValue: {
        action: 'set_deal_status',
        params: { status: 'lost', lost_reason_id: 5 },
        continue_on_error: false,
      },
    });
    expect(wrapper.text()).toContain('Lost reason');

    await wrapper.findAll('select').at(1).setValue('won');
    expect(lastEmit(wrapper).params).toEqual({ status: 'won' });
  });

  it('clears the stage when the pipeline changes', async () => {
    const wrapper = mountWith(ActionEditor, {
      modelValue: {
        action: 'move_deal',
        params: { pipeline_id: 1, pipeline_stage_id: 10, reopen: true },
        continue_on_error: false,
      },
    });
    await wrapper
      .findComponent({ name: 'ParamField' })
      .vm.$emit('update', 'pipeline_id', 2);

    expect(lastEmit(wrapper).params).toEqual({
      pipeline_id: 2,
      pipeline_stage_id: '',
      reopen: true,
    });
  });

  it('flags the params the validation reported', () => {
    const wrapper = mountWith(ActionEditor, {
      modelValue: {
        action: 'send_message',
        params: { content: '' },
        continue_on_error: false,
      },
      invalidParams: ['content'],
    });
    expect(wrapper.text()).toContain('This field is required.');
  });
});

describe('NodeInspector', () => {
  it('asks to select a block when nothing is selected', () => {
    const wrapper = mountWith(NodeInspector, { node: null });
    expect(wrapper.text()).toContain('Select a block to edit it');
  });

  it('edits the selected block and lists its issues', async () => {
    const node = {
      id: 'w',
      type: 'wait',
      data: { amount: 0, unit: 'hours' },
    };
    const wrapper = mountWith(NodeInspector, {
      node,
      issues: [{ nodeId: 'w', code: 'WAIT_AMOUNT' }],
    });
    expect(wrapper.text()).toContain('Enter how long to wait.');

    await wrapper.find('input[type="number"]').setValue('3');
    expect(wrapper.emitted('update:data').at(-1)[0]).toEqual({
      amount: 3,
      unit: 'hours',
    });

    await wrapper.find('button[aria-label="Delete block"]').trigger('click');
    expect(wrapper.emitted('delete')).toHaveLength(1);
  });
});
