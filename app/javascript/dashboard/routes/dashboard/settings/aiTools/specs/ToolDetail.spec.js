import { ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import ToolDetail from '../ToolDetail.vue';
import aiToolsAPI from 'dashboard/api/aiTools';

const mocks = vi.hoisted(() => ({
  alert: vi.fn(),
  guards: {},
  ask: vi.fn(),
}));

vi.mock('vue-router', () => ({
  onBeforeRouteLeave: guard => {
    mocks.guards.leave = guard;
  },
  onBeforeRouteUpdate: guard => {
    mocks.guards.update = guard;
  },
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key}:${params.count}` : key),
  }),
}));
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => mocks.alert(...args),
}));
vi.mock('dashboard/api/aiTools', () => ({
  default: { update: vi.fn(), delete: vi.fn() },
}));

const tool = (extra = {}) => ({
  id: 12,
  name: 'Consultar pedido',
  description: 'Consulta um pedido',
  active: false,
  allow_in_playground: true,
  slug: 'consultar_pedido',
  configuration: {
    method: 'POST',
    url: 'https://api.test/orders',
    timeout_seconds: 12,
    parameters: [
      { name: 'order_id', type: 'string', required: true, value_source: 'ai' },
    ],
    headers: { Accept: 'application/json' },
    secret_header_names: ['Authorization'],
  },
  ...extra,
});

const mountDetail = (source = tool(), linked = [], warnHandler = undefined) => {
  const workspace = {
    tools: ref([source]),
    agents: ref([{ id: 7, name: 'Vendas' }]),
    linkedAgents: vi.fn(() => linked),
    upsert: vi.fn(),
    removeTool: vi.fn().mockResolvedValue(),
    goToList: vi.fn(),
  };
  const wrapper = shallowMount(ToolDetail, {
    props: { tool: source },
    global: {
      renderStubDefaultSlot: true,
      config: warnHandler ? { warnHandler } : {},
      provide: { aiToolsWorkspace: workspace },
      stubs: {
        UnsavedChangesDialog: {
          template: '<div />',
          methods: { ask: (...args) => mocks.ask(...args) },
        },
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open: vi.fn(), close: vi.fn() },
        },
        ToolTestDialog: {
          template: '<div />',
          methods: { open: vi.fn() },
        },
      },
    },
  });
  return { wrapper, workspace };
};

const button = (wrapper, label) =>
  wrapper
    .findAllComponents({ name: 'Button' })
    .find(candidate => candidate.props('label') === label);
const disabled = component => component.attributes('disabled') === 'true';

beforeEach(() => {
  vi.clearAllMocks();
  mocks.guards = {};
});

// The child components are stubbed in these specs, so a template that points a prop at a name the script
// does not define (for example after renaming a constant) only shows up as a Vue warning.
it('renders every section without reading properties that do not exist', () => {
  const warnings = [];
  mountDetail(tool(), [], message => warnings.push(message));

  expect(warnings.filter(message => /not defined/.test(message))).toEqual([]);
});

it('loads the tool from the list, with its headers and parameters', () => {
  const { wrapper } = mountDetail();

  expect(wrapper.vm.form.configuration.url).toBe('https://api.test/orders');
  expect(wrapper.vm.headerRows).toHaveLength(2);
  expect(wrapper.vm.isDirty).toBe(false);
  expect(wrapper.text()).toContain('Consultar pedido');
});

it('keeps the parameters when the JSON mode holds invalid JSON', () => {
  const { wrapper } = mountDetail();

  wrapper.vm.parameterMode = 'json';
  wrapper.vm.parametersJson = '{invalid';
  wrapper.vm.switchParameterMode('visual');

  expect(wrapper.vm.form.configuration.parameters).toEqual([
    { name: 'order_id', type: 'string', required: true, value_source: 'ai' },
  ]);
  expect(wrapper.vm.isDirty).toBe(true);
});

it('shows how many assistants use the tool and lists them', () => {
  const { wrapper } = mountDetail(tool(), [{ id: 7, name: 'Vendas' }]);

  expect(wrapper.text()).toContain('AI_TOOLS.ASSISTANTS_COUNT:1');
  expect(wrapper.text()).toContain('Vendas');
});

it('only enables Save when there are valid changes', async () => {
  const { wrapper } = mountDetail();
  expect(disabled(button(wrapper, 'AI_TOOLS.SAVE'))).toBe(true);
  expect(disabled(button(wrapper, 'AI_HUB.DISCARD'))).toBe(true);

  wrapper.vm.form.description = 'Descrição atualizada';
  await wrapper.vm.$nextTick();
  expect(wrapper.text()).toContain('AI_TOOLS.UNSAVED');
  expect(disabled(button(wrapper, 'AI_TOOLS.SAVE'))).toBe(false);

  wrapper.vm.form.configuration.url = 'ftp://invalid';
  await wrapper.vm.$nextTick();
  expect(wrapper.vm.validationError).toBe('AI_TOOLS.URL_INVALID');
  expect(disabled(button(wrapper, 'AI_TOOLS.SAVE'))).toBe(true);
  await wrapper.vm.save();
  expect(aiToolsAPI.update).not.toHaveBeenCalled();
});

it('preserves the existing save payload, refreshes the list and clears the unsaved state', async () => {
  const { wrapper, workspace } = mountDetail();
  wrapper.vm.form.description = 'Descrição atualizada';
  const saved = tool({ description: 'Descrição atualizada' });
  aiToolsAPI.update.mockResolvedValue({ data: saved });

  await wrapper.vm.save();

  expect(aiToolsAPI.update).toHaveBeenCalledWith(
    12,
    expect.objectContaining({
      ai_tool: expect.objectContaining({
        name: 'Consultar pedido',
        description: 'Descrição atualizada',
        configuration: expect.objectContaining({
          method: 'POST',
          url: 'https://api.test/orders',
          timeout_seconds: 12,
        }),
      }),
    })
  );
  expect(workspace.upsert).toHaveBeenCalledWith(saved);
  expect(wrapper.vm.isDirty).toBe(false);
  expect(mocks.alert).toHaveBeenCalledWith('AI_TOOLS.SAVED');
});

it('keeps the draft and shows the server message when saving fails', async () => {
  const { wrapper, workspace } = mountDetail();
  wrapper.vm.form.description = 'Outra descrição';
  aiToolsAPI.update.mockRejectedValue({
    response: { data: { message: 'A tool with this name already exists.' } },
  });

  await wrapper.vm.save();

  expect(wrapper.vm.error).toBe('A tool with this name already exists.');
  expect(wrapper.vm.isDirty).toBe(true);
  expect(workspace.upsert).not.toHaveBeenCalled();
});

it('discards the pending changes and goes back to the saved version', async () => {
  const { wrapper } = mountDetail();
  wrapper.vm.form.name = 'Renamed';
  wrapper.vm.form.configuration.url = 'https://other.test';
  await wrapper.vm.$nextTick();

  button(wrapper, 'AI_HUB.DISCARD').vm.$emit('click');
  await wrapper.vm.$nextTick();

  expect(wrapper.vm.form.name).toBe('Consultar pedido');
  expect(wrapper.vm.form.configuration.url).toBe('https://api.test/orders');
  expect(wrapper.vm.isDirty).toBe(false);
});

it('toggles active right away without marking the form as changed, and reverts on error', async () => {
  const { wrapper, workspace } = mountDetail();
  aiToolsAPI.update.mockResolvedValueOnce({ data: tool({ active: true }) });

  await wrapper.vm.toggleActive();
  expect(aiToolsAPI.update).toHaveBeenCalledWith(12, {
    ai_tool: { active: true },
  });
  expect(wrapper.vm.form.active).toBe(true);
  expect(workspace.upsert).toHaveBeenCalled();
  expect(wrapper.vm.isDirty).toBe(false);

  aiToolsAPI.update.mockRejectedValueOnce(new Error('network'));
  await wrapper.vm.toggleActive();
  expect(wrapper.vm.form.active).toBe(true);
  expect(mocks.alert).toHaveBeenCalledWith('AI_TOOLS.SAVE_ERROR');
});

it('deletes through the API and hands the navigation to the list without asking about unsaved changes', async () => {
  const { wrapper, workspace } = mountDetail();
  wrapper.vm.form.name = 'Edited and then deleted';
  aiToolsAPI.delete.mockResolvedValue({});

  await wrapper.vm.remove();

  expect(aiToolsAPI.delete).toHaveBeenCalledWith(12);
  expect(workspace.removeTool).toHaveBeenCalledWith(12);
  expect(await mocks.guards.leave()).toBe(true);
  expect(mocks.ask).not.toHaveBeenCalled();
});

it('keeps the tool and shows an error when deleting fails', async () => {
  const { wrapper, workspace } = mountDetail();
  aiToolsAPI.delete.mockRejectedValue(new Error('network'));

  await wrapper.vm.remove();
  await flushPromises();

  expect(workspace.removeTool).not.toHaveBeenCalled();
  expect(wrapper.vm.actionError).toBe('AI_TOOLS.DELETE_ERROR');
});

it('asks before leaving or switching to another tool with unsaved changes', async () => {
  const { wrapper } = mountDetail();
  expect(await mocks.guards.leave()).toBe(true);
  expect(await mocks.guards.update()).toBe(true);
  expect(mocks.ask).not.toHaveBeenCalled();

  wrapper.vm.form.name = 'Changed';
  mocks.ask.mockResolvedValueOnce(false);
  expect(await mocks.guards.update()).toBe(false);
  mocks.ask.mockResolvedValueOnce(true);
  expect(await mocks.guards.leave()).toBe(true);
  expect(mocks.ask).toHaveBeenCalledTimes(2);
});
