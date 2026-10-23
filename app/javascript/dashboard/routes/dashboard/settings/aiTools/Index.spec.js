import { flushPromises, shallowMount } from '@vue/test-utils';
import Index from './Index.vue';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import aiToolsAPI from 'dashboard/api/aiTools';

const mocks = vi.hoisted(() => ({
  push: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key}:${params.count}` : key),
  }),
}));

vi.mock('dashboard/api/aiAgents', () => ({
  default: { get: vi.fn() },
}));

vi.mock('dashboard/api/aiTools', () => ({
  default: { get: vi.fn(), update: vi.fn(), delete: vi.fn() },
}));

const mountPage = () =>
  shallowMount(Index, {
    global: {
      stubs: {
        Button: { template: '<button><slot /></button>' },
        Dialog: {
          template: '<div />',
          methods: { open: vi.fn(), close: vi.fn() },
        },
        Input: { template: '<input />' },
      },
    },
  });

beforeEach(() => {
  vi.clearAllMocks();
  aiToolsAPI.get.mockResolvedValue({
    data: {
      tools: [
        {
          id: 1,
          name: 'Pedidos',
          description: 'Consulta pedidos',
          active: true,
          configuration: { method: 'GET', url: 'https://api.test/orders' },
        },
        {
          id: 2,
          name: 'Cobrança',
          description: 'Envia cobranças',
          active: false,
          configuration: { method: 'POST', url: 'https://api.test/billing' },
        },
      ],
    },
  });
  aiAgentsAPI.get.mockResolvedValue({
    data: { agents: [{ id: 8, name: 'Vendas', tools: [{ id: 1 }] }] },
  });
});

it('filters tools locally by search and status without changing the API contract', async () => {
  const wrapper = mountPage();
  await flushPromises();

  expect(wrapper.vm.filteredTools).toHaveLength(2);
  wrapper.vm.search = 'cobrança';
  expect(wrapper.vm.filteredTools.map(tool => tool.id)).toEqual([2]);
  wrapper.vm.search = '';
  wrapper.vm.status = 'active';
  expect(wrapper.vm.filteredTools.map(tool => tool.id)).toEqual([1]);
  expect(wrapper.vm.linkedAgents(wrapper.vm.tools[0])).toHaveLength(1);
});

it('keeps edit, logs and new-tool navigation on the existing routes', async () => {
  const wrapper = mountPage();
  await flushPromises();

  wrapper.vm.openEditor(wrapper.vm.tools[0]);
  expect(mocks.push).toHaveBeenCalledWith({
    name: 'ai_tool_edit',
    params: { toolId: 1 },
  });
  wrapper.vm.openEditor();
  expect(mocks.push).toHaveBeenCalledWith({ name: 'ai_tool_new' });
  wrapper.vm.openLogs();
  expect(mocks.push).toHaveBeenCalledWith({ name: 'ai_tool_logs' });
});
