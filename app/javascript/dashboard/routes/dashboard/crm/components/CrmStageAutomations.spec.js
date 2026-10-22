import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createStore } from 'vuex';
import CrmStageAutomations, {
  isAutomationValid,
} from './CrmStageAutomations.vue';
import { pipelinesAPI } from 'dashboard/api/crm';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';

vi.mock('dashboard/api/crm', () => ({ pipelinesAPI: { get: vi.fn() } }));

const store = createStore({
  getters: {
    'agents/getAgents': () => [{ id: 7, name: 'Maria' }],
    'labels/getLabels': () => [{ title: 'vip' }],
  },
});

let wrapper;

// Mirrors a parent using v-model:automations so updates flow back into the props.
const mountEditor = (automations = []) =>
  mount(CrmStageAutomations, {
    props: {
      automations,
      'onUpdate:automations': value => wrapper.setProps({ automations: value }),
    },
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
        store,
      ],
    },
  });

const clickButton = async (target, text) => {
  await target
    .findAll('button')
    .find(button => button.text().startsWith(text))
    .trigger('click');
  await flushPromises();
};

describe('isAutomationValid', () => {
  it.each([
    [{ type: 'set_status', status: 'won' }, true],
    [{ type: 'set_status', status: 'archived' }, false],
    [{ type: 'assign_owner', user_id: 7 }, true],
    [{ type: 'assign_owner', user_id: null }, false],
    [
      {
        type: 'create_activity',
        activity_type: 'call',
        title: 'Call',
        due_in_hours: 2,
      },
      true,
    ],
    [
      {
        type: 'create_activity',
        activity_type: 'call',
        title: ' ',
        due_in_hours: 2,
      },
      false,
    ],
    [{ type: 'add_label', label: 'vip' }, true],
    [{ type: 'add_label', label: '' }, false],
    [{ type: 'set_ai_state', state: 'human' }, true],
    [{ type: 'send_message', content: 'Olá {{first_name}}' }, true],
    [{ type: 'send_message', content: '  ' }, false],
    [{ type: 'move_stage', pipeline_id: 1, stage_id: 2 }, true],
    [{ type: 'move_stage', pipeline_id: 1, stage_id: null }, false],
    [{ type: 'send_webhook', url: 'https://example.com/hook' }, true],
    [{ type: 'send_webhook', url: 'example.com/hook' }, false],
    [{ type: 'send_webhook', url: '' }, false],
    [{ type: 'unknown' }, false],
  ])('validates %j as %s', (action, expected) => {
    expect(isAutomationValid(action)).toBe(expected);
  });
});

describe('CrmStageAutomations', () => {
  beforeEach(() => {
    pipelinesAPI.get.mockResolvedValue({
      data: [
        {
          id: 1,
          name: 'Sales',
          stages: [
            { id: 10, name: 'Lead' },
            { id: 11, name: 'Won' },
          ],
        },
      ],
    });
  });

  it('adds an action, resets its fields when the type changes and removes it', async () => {
    wrapper = mountEditor();
    await clickButton(wrapper, 'Automações');
    await clickButton(wrapper, pt.CRM.AUTOMATION_ADD);
    expect(wrapper.props('automations')).toEqual([
      { type: 'set_status', status: 'won' },
    ]);

    wrapper
      .findAllComponents({ name: 'ComboBox' })[0]
      .vm.$emit('update:modelValue', 'send_webhook');
    await flushPromises();
    expect(wrapper.props('automations')).toEqual([
      { type: 'send_webhook', url: '' },
    ]);
    expect(wrapper.find('input[type="url"]').exists()).toBe(true);

    await wrapper.find('button[aria-label]').trigger('click');
    expect(wrapper.props('automations')).toEqual([]);
  });

  it('loads pipelines only when a move action exists', async () => {
    wrapper = mountEditor([{ type: 'set_status', status: 'won' }]);
    await flushPromises();
    expect(pipelinesAPI.get).not.toHaveBeenCalled();

    wrapper = mountEditor([
      { type: 'move_stage', pipeline_id: 1, stage_id: 10 },
    ]);
    await flushPromises();
    expect(pipelinesAPI.get).toHaveBeenCalledTimes(1);
  });
});
