import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import automationWorkflowsAPI, {
  workflowLostReasonsAPI,
} from 'dashboard/api/automationWorkflows';
import { useAlert } from 'dashboard/composables';
import messages from 'dashboard/i18n/locale/pt_BR/automation.json';
import WorkflowList from './WorkflowList.vue';

const push = vi.fn();

vi.mock('vue-router', async importOriginal => ({
  ...(await importOriginal()),
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/automationWorkflows', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
  workflowLostReasonsAPI: { get: vi.fn() },
}));

const Layout = {
  props: ['isLoading', 'noRecordsFound', 'noRecordsMessage'],
  template:
    '<div><slot name="header" /><p v-if="noRecordsFound" data-test="empty">{{ noRecordsMessage }}</p><slot v-else name="body" /><slot /></div>',
};
const Header = {
  template: '<div><slot name="actions" /></div>',
};
const Button = {
  inheritAttrs: false,
  props: ['label'],
  template: '<button v-bind="$attrs">{{ label }}</button>',
};
const Switch = {
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template:
    '<button data-test="toggle" @click="$emit(\'update:modelValue\', !modelValue)" />',
};
const Dialog = {
  emits: ['confirm'],
  setup(_, { expose }) {
    expose({ open: vi.fn(), close: vi.fn() });
  },
  template:
    '<div><button data-test="confirm" @click="$emit(\'confirm\')" /></div>',
};
const TemplateDialog = {
  emits: ['pick'],
  setup(_, { expose }) {
    expose({ open: vi.fn(), close: vi.fn() });
  },
  template: '<div />',
};

const mountList = () =>
  mount(WorkflowList, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: {
        SettingsLayout: Layout,
        BaseSettingsHeader: Header,
        AutomationSectionSwitch: true,
        Button,
        ToggleSwitch: Switch,
        Switch,
        Dialog,
        WorkflowTemplateDialog: TemplateDialog,
      },
    },
  });

const lostWorkflow = {
  id: 4,
  name: 'Roteamento por motivo',
  description: 'Perdidos',
  active: false,
  graph: { nodes: [], edges: [] },
  trigger_events: ['crm_deal_lost', 'webhook'],
  last_run: { id: 9, status: 'failed', started_at: '2026-10-29T12:00:00Z' },
};

beforeEach(() => {
  vi.clearAllMocks();
  automationWorkflowsAPI.get.mockResolvedValue({ data: [lostWorkflow] });
});

describe('WorkflowList', () => {
  it('lists the workflows with their triggers and last run', async () => {
    const wrapper = mountList();
    await flushPromises();

    const text = wrapper.text();
    expect(text).toContain('Roteamento por motivo');
    expect(text).toContain('Negócio perdido, Webhook recebido');
    expect(text).toContain('Falhou');
  });

  it('shows the empty message when there is no workflow', async () => {
    automationWorkflowsAPI.get.mockResolvedValue({ data: [] });
    const wrapper = mountList();
    await flushPromises();

    expect(wrapper.find('[data-test="empty"]').text()).toContain(
      'Nenhum workflow'
    );
  });

  it('turns a workflow on and refreshes it from the response', async () => {
    automationWorkflowsAPI.update.mockResolvedValue({
      data: { ...lostWorkflow, active: true },
    });
    const wrapper = mountList();
    await flushPromises();

    await wrapper.find('[data-test="toggle"]').trigger('click');
    await flushPromises();

    expect(automationWorkflowsAPI.update).toHaveBeenCalledWith(4, {
      automation_workflow: { active: true },
    });
    expect(useAlert).toHaveBeenCalledWith('Workflow ligado');
  });

  it('shows the server message when the workflow cannot be turned on', async () => {
    automationWorkflowsAPI.update.mockRejectedValue({
      response: { data: { message: 'Graph is invalid' } },
    });
    const wrapper = mountList();
    await flushPromises();

    await wrapper.find('[data-test="toggle"]').trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith('Graph is invalid');
  });

  it('creates a workflow from the lost reason template and opens it', async () => {
    workflowLostReasonsAPI.get.mockResolvedValue({
      data: [{ id: 1, name: 'Sem orçamento', active: true }],
    });
    automationWorkflowsAPI.create.mockResolvedValue({ data: { id: 12 } });
    const wrapper = mountList();
    await flushPromises();

    const { WORKFLOW_TEMPLATES } = await import('./templates');
    const template = WORKFLOW_TEMPLATES.find(
      item => item.key === 'lost_reason_routing'
    );
    await wrapper.findComponent(TemplateDialog).vm.$emit('pick', template);
    await flushPromises();

    const { automation_workflow: payload } =
      automationWorkflowsAPI.create.mock.calls[0][0];
    expect(payload.name).toBe('Rotear negócios perdidos por motivo');
    expect(payload.active).toBe(false);
    expect(payload.graph.nodes.map(node => node.type)).toEqual([
      'trigger',
      'switch',
      'action',
    ]);
    expect(payload.graph.nodes[1].data.cases[0]).toMatchObject({
      value: '1',
      label: 'Sem orçamento',
    });
    expect(push).toHaveBeenCalledWith({
      name: 'automation_workflow_edit',
      params: { accountId: '1', workflowId: 12 },
    });
  });

  it('deletes a workflow after confirming', async () => {
    automationWorkflowsAPI.delete.mockResolvedValue({});
    const wrapper = mountList();
    await flushPromises();

    const deleteButton = wrapper
      .findAll('button')
      .find(button => button.attributes('icon') === 'i-woot-bin');
    await deleteButton.trigger('click');
    await wrapper
      .findAllComponents(Dialog)
      .at(0)
      .find('[data-test="confirm"]')
      .trigger('click');
    await flushPromises();

    expect(automationWorkflowsAPI.delete).toHaveBeenCalledWith(4);
    expect(wrapper.text()).not.toContain('Roteamento por motivo');
  });
});
