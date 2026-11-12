import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import Index from '../Index.vue';
import EmptyRoute from '../../aiShared/EmptyRoute';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import aiToolsAPI from 'dashboard/api/aiTools';

const mocks = vi.hoisted(() => ({ openCreate: vi.fn() }));

vi.mock('dashboard/composables/useAccount', async () => {
  const { computed } = await import('vue');
  const { useRoute } = await import('vue-router');
  return {
    useAccount: () => {
      const route = useRoute();
      return { accountId: computed(() => route.params.accountId) };
    },
  };
});
vi.mock('vue-i18n', async importOriginal => ({
  ...(await importOriginal()),
  useI18n: () => ({
    t: (key, params) => (params ? `${key}:${params.count}` : key),
  }),
}));
vi.mock('dashboard/api/aiAgents', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/aiTools', () => ({ default: { get: vi.fn() } }));

const tool = (id, extra = {}) => ({
  id,
  name: `Tool ${id}`,
  description: `Does ${id}`,
  active: id % 2 === 1,
  configuration: { method: 'POST', url: `https://api.test/${id}` },
  ...extra,
});
// The API returns tools newest first; they carry no created_at, so id is the order.
const toolList = [tool(3), tool(2, { name: 'Cobrança' }), tool(1)];

const DetailStub = {
  name: 'DetailStub',
  props: ['toolId'],
  template: '<p data-test="detail">{{ toolId }}</p>',
};
const LogsStub = { template: '<p data-test="logs">logs</p>' };
const stubs = {
  Button: {
    props: ['label', 'disabled'],
    emits: ['click'],
    template:
      '<button :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
  },
  Input: {
    props: ['size', 'modelValue', 'placeholder'],
    emits: ['update:modelValue'],
    template:
      '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  },
  ToolCreateDialog: {
    template: '<div />',
    methods: { open: () => mocks.openCreate() },
  },
};

const buildRouter = () =>
  createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/accounts/:accountId/ai-tools',
        component: Index,
        children: [
          { path: '', name: 'ai_tools_settings', component: EmptyRoute },
          { path: 'logs', name: 'ai_tool_logs', component: LogsStub },
          {
            path: ':toolId(\\d+)',
            name: 'ai_tool_detail',
            component: DetailStub,
            props: true,
          },
        ],
      },
    ],
  });

const mountAt = async path => {
  const router = buildRouter();
  router.push(path);
  await router.isReady();
  const replace = vi.spyOn(router, 'replace');
  const push = vi.spyOn(router, 'push');
  const wrapper = mount(
    { template: '<router-view />' },
    { global: { plugins: [router], stubs } }
  );
  await flushPromises();
  return { router, wrapper, replace, push };
};

const listNames = wrapper =>
  wrapper.findAll('nav a').map(link => link.find('.font-semibold').text());

beforeEach(() => {
  vi.clearAllMocks();
  aiToolsAPI.get.mockResolvedValue({ data: { tools: toolList } });
  aiAgentsAPI.get.mockResolvedValue({
    data: { agents: [{ id: 8, name: 'Vendas', tools: [{ id: 1 }] }] },
  });
});

describe('entering the screen', () => {
  it('opens the most recent tool with replace', async () => {
    const { router, wrapper, replace, push } = await mountAt(
      '/accounts/1/ai-tools'
    );

    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools/3');
    expect(replace).toHaveBeenCalledTimes(1);
    expect(push).not.toHaveBeenCalled();
    expect(wrapper.find('[data-test="detail"]').text()).toBe('3');
    expect(listNames(wrapper)).toEqual(['Tool 3', 'Cobrança', 'Tool 1']);
  });

  it('sorts by id when the payload has no creation date, even if the API order differs', async () => {
    aiToolsAPI.get.mockResolvedValue({
      data: { tools: [tool(1), tool(5), tool(2)] },
    });
    const { router } = await mountAt('/accounts/1/ai-tools');
    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools/5');
  });

  it('keeps a deep link and highlights the open tool', async () => {
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/ai-tools/2'
    );

    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools/2');
    expect(replace).not.toHaveBeenCalled();
    expect(wrapper.find('nav a[aria-current="page"]').text()).toContain(
      'Cobrança'
    );
  });

  it('replaces an id that does not exist with the most recent tool', async () => {
    const { router, replace } = await mountAt('/accounts/1/ai-tools/99');

    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools/3');
    expect(replace).toHaveBeenCalledTimes(1);
  });

  it('does not take the logs page for a tool id and does not redirect it', async () => {
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/ai-tools/logs'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-tools/logs'
    );
    expect(replace).not.toHaveBeenCalled();
    expect(wrapper.find('[data-test="logs"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="detail"]').exists()).toBe(false);
  });
});

describe('empty list', () => {
  beforeEach(() => {
    aiToolsAPI.get.mockResolvedValue({ data: { tools: [] } });
  });

  it('shows the empty state with a create button and does not redirect', async () => {
    const { router, wrapper, replace } = await mountAt('/accounts/1/ai-tools');

    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools');
    expect(replace).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('AI_TOOLS.EMPTY');
    const create = wrapper
      .findAll('button')
      .filter(button => button.text() === 'AI_TOOLS.CREATE');
    await create[create.length - 1].trigger('click');
    expect(mocks.openCreate).toHaveBeenCalled();
  });

  it('sends an unknown id to the index once and stops there', async () => {
    const { router, replace } = await mountAt('/accounts/1/ai-tools/7');

    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools');
    expect(replace).toHaveBeenCalledTimes(1);
  });

  it('still opens the logs page', async () => {
    const { wrapper } = await mountAt('/accounts/1/ai-tools/logs');
    expect(wrapper.find('[data-test="logs"]').exists()).toBe(true);
  });
});

describe('loading', () => {
  it('shows a skeleton, never the empty state, until the list arrives', async () => {
    let resolveList;
    aiToolsAPI.get.mockReturnValue(
      new Promise(resolve => {
        resolveList = resolve;
      })
    );
    const { router, wrapper } = await mountAt('/accounts/1/ai-tools');

    expect(wrapper.find('[role="status"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('AI_TOOLS.EMPTY');
    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools');

    resolveList({ data: { tools: toolList } });
    await flushPromises();
    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools/3');
  });

  it('shows an error with retry and keeps the URL when the list fails', async () => {
    aiToolsAPI.get.mockRejectedValueOnce(new Error('network'));
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/ai-tools/3'
    );

    expect(wrapper.text()).toContain('AI_TOOLS.LOAD_ERROR');
    expect(replace).not.toHaveBeenCalled();
    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools/3');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'AI_TOOLS.RETRY')
      .trigger('click');
    await flushPromises();
    expect(wrapper.find('[data-test="detail"]').text()).toBe('3');
  });
});

describe('navigation and filters', () => {
  it('opens another tool with push', async () => {
    const { router, wrapper, push } = await mountAt('/accounts/1/ai-tools');

    await wrapper.findAll('nav a')[2].trigger('click');
    await flushPromises();

    expect(push).toHaveBeenCalled();
    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools/1');
  });

  it('opens the logs page from the button on top of the list', async () => {
    const { router, wrapper } = await mountAt('/accounts/1/ai-tools/3');

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'AI_TOOLS.LOGS_TAB')
      .trigger('click');
    await flushPromises();

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-tools/logs'
    );
  });

  it('filters the list by search and by status without touching the URL', async () => {
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/ai-tools/3'
    );
    replace.mockClear();

    await wrapper.find('input').setValue('cobrança');
    expect(listNames(wrapper)).toEqual(['Cobrança']);

    await wrapper.find('input').setValue('');
    await wrapper.find('select').setValue('active');
    expect(listNames(wrapper)).toEqual(['Tool 3', 'Tool 1']);

    expect(replace).not.toHaveBeenCalled();
    expect(router.currentRoute.value.fullPath).toBe('/accounts/1/ai-tools/3');
  });
});
