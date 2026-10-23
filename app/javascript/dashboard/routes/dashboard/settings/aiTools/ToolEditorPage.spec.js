import { flushPromises, shallowMount } from '@vue/test-utils';
import { reactive } from 'vue';
import ToolEditorPage from './ToolEditorPage.vue';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import aiToolsAPI from 'dashboard/api/aiTools';

const mocks = vi.hoisted(() => ({
  route: null,
  push: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/api/aiAgents', () => ({
  default: { get: vi.fn() },
}));

vi.mock('dashboard/api/aiTools', () => ({
  default: { show: vi.fn(), create: vi.fn(), update: vi.fn(), test: vi.fn() },
}));

const mountPage = () =>
  shallowMount(ToolEditorPage, {
    global: {
      stubs: {
        Button: { template: '<button><slot /></button>' },
        ComboBox: {
          props: ['modelValue', 'label', 'options', 'disabled'],
          template: '<div />',
        },
        Input: { template: '<input />' },
        Switch: { template: '<input type="checkbox" />' },
        TextArea: { template: '<textarea />' },
      },
    },
  });

beforeEach(() => {
  vi.clearAllMocks();
  mocks.route = reactive({ params: { toolId: '12' } });
  aiAgentsAPI.get.mockResolvedValue({
    data: { agents: [{ id: 7, name: 'Vendas' }] },
  });
  aiToolsAPI.show.mockResolvedValue({
    data: {
      id: 12,
      name: 'Consultar pedido',
      description: 'Consulta um pedido',
      active: true,
      allow_in_playground: true,
      configuration: {
        method: 'POST',
        url: 'https://api.test/orders',
        timeout_seconds: 12,
        parameters: [
          {
            name: 'order_id',
            type: 'string',
            required: true,
            value_source: 'ai',
          },
        ],
        headers: { Accept: 'application/json' },
        secret_header_names: ['Authorization'],
      },
    },
  });
  aiToolsAPI.test.mockResolvedValue({
    data: { status: 200, success: true, result: 'ok', duration_ms: 34 },
  });
  aiToolsAPI.update.mockResolvedValue({ data: {} });
});

it('keeps values while switching tabs and does not erase parameters after invalid JSON', async () => {
  const wrapper = mountPage();
  await flushPromises();

  expect(wrapper.vm.form.configuration.url).toBe('https://api.test/orders');
  expect(wrapper.vm.headerRows).toHaveLength(2);
  wrapper.vm.selectTab('parameters');
  wrapper.vm.parameterMode = 'json';
  wrapper.vm.parametersJson = '{invalid';
  wrapper.vm.switchParameterMode('visual');

  expect(wrapper.vm.form.configuration.parameters).toEqual([
    { name: 'order_id', type: 'string', required: true, value_source: 'ai' },
  ]);
  wrapper.vm.selectTab('request');
  expect(wrapper.vm.activeTab).toBe('request');
  expect(wrapper.vm.isDirty).toBe(true);
});

it('preserves the existing save payload and runs the selected agent test', async () => {
  const wrapper = mountPage();
  await flushPromises();

  wrapper.vm.form.description = 'Descrição atualizada';
  await wrapper.vm.save();
  expect(aiToolsAPI.update).toHaveBeenCalledWith(
    '12',
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

  wrapper.vm.testArguments = '{"order_id":"42"}';
  await wrapper.vm.runTest();
  expect(aiToolsAPI.test).toHaveBeenCalledWith(
    '12',
    7,
    { order_id: '42' },
    null
  );
  expect(wrapper.vm.testResult.result).toBe('ok');
});
