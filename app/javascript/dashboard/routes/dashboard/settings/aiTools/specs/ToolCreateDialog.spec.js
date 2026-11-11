import { flushPromises, shallowMount } from '@vue/test-utils';
import ToolCreateDialog from '../ToolCreateDialog.vue';
import aiToolsAPI from 'dashboard/api/aiTools';

const mocks = vi.hoisted(() => ({ open: vi.fn(), close: vi.fn() }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/aiTools', () => ({ default: { create: vi.fn() } }));

const mountDialog = () =>
  shallowMount(ToolCreateDialog, {
    global: {
      renderStubDefaultSlot: true,
      stubs: {
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open: mocks.open, close: mocks.close },
        },
      },
    },
  });

const fill = wrapper => {
  wrapper.vm.draft.name = 'Consultar pedido';
  wrapper.vm.draft.description = 'Consulta um pedido pelo número';
  wrapper.vm.draft.configuration.method = 'POST';
  wrapper.vm.draft.configuration.url = 'https://api.test/orders';
};

beforeEach(() => {
  vi.clearAllMocks();
});

it('needs the name, the description and a valid HTTP URL, like the editor', () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  expect(mocks.open).toHaveBeenCalled();
  expect(wrapper.vm.canSave).toBe(false);

  fill(wrapper);
  expect(wrapper.vm.canSave).toBe(true);

  wrapper.vm.draft.configuration.url = 'ftp://files.test';
  expect(wrapper.vm.canSave).toBe(false);
  wrapper.vm.draft.configuration.url = 'https://api.test';
  wrapper.vm.draft.name = '   ';
  expect(wrapper.vm.canSave).toBe(false);
});

it('creates an inactive tool with the default request settings and reports it', async () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  fill(wrapper);
  const created = { id: 31, name: 'Consultar pedido' };
  aiToolsAPI.create.mockResolvedValue({ data: created });

  await wrapper.vm.create();

  expect(aiToolsAPI.create).toHaveBeenCalledWith({
    ai_tool: {
      name: 'Consultar pedido',
      description: 'Consulta um pedido pelo número',
      active: false,
      allow_in_playground: false,
      configuration: {
        method: 'POST',
        url: 'https://api.test/orders',
        timeout_seconds: 10,
        parameters: [],
        headers: {},
        query_params: {},
        body: {},
      },
    },
  });
  expect(mocks.close).toHaveBeenCalled();
  expect(wrapper.emitted('created')).toEqual([[created]]);
});

it('stays open and keeps the fields when the server rejects the tool', async () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  fill(wrapper);
  aiToolsAPI.create.mockRejectedValue({
    response: { data: { message: 'A tool with this name already exists.' } },
  });

  await wrapper.vm.create();
  await flushPromises();

  expect(mocks.close).not.toHaveBeenCalled();
  expect(wrapper.emitted('created')).toBeUndefined();
  expect(wrapper.text()).toContain('A tool with this name already exists.');
  expect(wrapper.vm.draft.name).toBe('Consultar pedido');
});

it('starts empty every time it is opened', () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  fill(wrapper);
  wrapper.vm.open();
  expect(wrapper.vm.draft.name).toBe('');
});
