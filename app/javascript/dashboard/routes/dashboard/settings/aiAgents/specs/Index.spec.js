import { reactive } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import Index from '../Index.vue';
import EmptyRoute from '../../aiShared/EmptyRoute';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import voiceAgentsAPI from 'dashboard/api/voiceAgents';

const mocks = vi.hoisted(() => ({ accounts: null, openCreate: vi.fn() }));

vi.mock('dashboard/composables/useAccount', async () => {
  const { computed: vueComputed } = await import('vue');
  const { useRoute: useCurrentRoute } = await import('vue-router');
  return {
    useAccount: () => {
      const route = useCurrentRoute();
      return {
        accountId: vueComputed(() => route.params.accountId),
        currentAccount: vueComputed(
          () => mocks.accounts[route.params.accountId]
        ),
      };
    },
  };
});
vi.mock('vuex', () => ({
  useStore: () => ({ dispatch: vi.fn().mockResolvedValue(true), getters: {} }),
}));
vi.mock('vue-i18n', async importOriginal => ({
  ...(await importOriginal()),
  useI18n: () => ({ t: key => key }),
}));
vi.mock('dashboard/api/aiAgents', () => ({
  default: { get: vi.fn(), tools: vi.fn() },
}));
vi.mock('dashboard/api/voiceAgents', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/knowledgeBases', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/crm', () => ({ pipelinesAPI: { get: vi.fn() } }));

const agent = (id, created, extra = {}) => ({
  id,
  name: `Agent ${id}`,
  provider: 'openai',
  model: 'gpt-4.1',
  active: id % 2 === 1,
  created_at: created,
  inboxes: [],
  ...extra,
});
// The API returns agents ordered by name, not by creation date.
const textList = [
  agent(1, '2026-01-01T10:00:00Z'),
  agent(3, '2026-03-01T10:00:00Z'),
  agent(2, '2026-02-01T10:00:00Z'),
];
const voiceList = [
  agent(10, '2026-01-01T10:00:00Z', { provider: 'vapi' }),
  agent(11, '2026-04-01T10:00:00Z', { provider: 'vapi' }),
];

const DetailStub = {
  name: 'DetailStub',
  props: ['agentId'],
  template: '<p data-test="detail">{{ agentId }}</p>',
};
const stubs = {
  Button: {
    props: ['label', 'disabled'],
    emits: ['click'],
    template:
      '<button :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
  },
  Input: {
    props: ['size', 'modelValue', 'placeholder'],
    template: '<input />',
  },
  Dialog: { template: '<div />' },
  TextCredentials: { template: '<div />' },
  AgentCreateDialog: {
    template: '<div />',
    methods: { open: () => mocks.openCreate() },
  },
};

const buildRouter = () =>
  createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/accounts/:accountId/ai-agents',
        component: Index,
        children: [
          { path: '', name: 'ai_agents_settings', component: EmptyRoute },
          {
            path: ':agentId(\\d+)',
            name: 'ai_agent_detail',
            component: DetailStub,
            props: true,
          },
        ],
      },
      {
        path: '/accounts/:accountId/saas-ai',
        name: 'saas_ai_settings',
        component: { render: () => null },
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
  mocks.accounts = reactive({
    1: { features: { text_ai: true, voice_ai: true } },
    2: { features: { voice_ai: true } },
    3: { features: {} },
  });
  aiAgentsAPI.get.mockResolvedValue({
    data: { agents: textList, text: { mode: 'byok' } },
  });
  aiAgentsAPI.tools.mockResolvedValue({ data: { tools: [] } });
  voiceAgentsAPI.get.mockResolvedValue({
    data: {
      agents: voiceList,
      providers: ['vapi'],
      duration_range: [10, 3600],
    },
  });
});

describe('entering the screen', () => {
  it('opens the most recent assistant with replace and lists them newest first', async () => {
    const { router, wrapper, replace, push } = await mountAt(
      '/accounts/1/ai-agents?type=text'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/3?type=text'
    );
    expect(replace).toHaveBeenCalledTimes(1);
    expect(push).not.toHaveBeenCalled();
    expect(listNames(wrapper)).toEqual(['Agent 3', 'Agent 2', 'Agent 1']);
    expect(wrapper.find('[data-test="detail"]').text()).toBe('3');
  });

  it('defaults a link without type to text and keeps other query parameters', async () => {
    const { router } = await mountAt('/accounts/1/ai-agents?other=keep');
    await flushPromises();

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/3?other=keep&type=text'
    );
  });

  it('keeps a deep link and highlights the open assistant in the list', async () => {
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/ai-agents/2?type=text'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/2?type=text'
    );
    expect(replace).not.toHaveBeenCalled();
    const current = wrapper.find('nav a[aria-current="page"]');
    expect(current.text()).toContain('Agent 2');
    expect(wrapper.find('[data-test="detail"]').text()).toBe('2');
  });

  it('replaces an id that does not exist with the most recent one', async () => {
    const { router, replace } = await mountAt(
      '/accounts/1/ai-agents/99?type=text'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/3?type=text'
    );
    expect(replace).toHaveBeenCalledTimes(1);
  });

  it('replaces the id of the other type (a text agent opened as voice)', async () => {
    const { router, wrapper } = await mountAt(
      '/accounts/1/ai-agents/3?type=voice'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/11?type=voice'
    );
    expect(listNames(wrapper)).toEqual(['Agent 11', 'Agent 10']);
  });
});

describe('empty list', () => {
  beforeEach(() => {
    aiAgentsAPI.get.mockResolvedValue({
      data: { agents: [], text: { mode: 'byok' } },
    });
  });

  it('shows the empty state with a create button and does not redirect', async () => {
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/ai-agents?type=text'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents?type=text'
    );
    expect(replace).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('AI_AGENTS.EMPTY');
    const create = wrapper
      .findAll('button')
      .filter(button => button.text() === 'AI_AGENTS.CREATE');
    expect(create.length).toBeGreaterThan(0);
    await create[create.length - 1].trigger('click');
    expect(mocks.openCreate).toHaveBeenCalled();
  });

  it('sends an unknown id to the index once and stops there', async () => {
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/ai-agents/5?type=text'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents?type=text'
    );
    expect(replace).toHaveBeenCalledTimes(1);
    expect(wrapper.text()).toContain('AI_AGENTS.EMPTY');
  });
});

describe('loading', () => {
  it('shows a skeleton, never the empty state, until the list arrives', async () => {
    let resolveList;
    aiAgentsAPI.get.mockReturnValue(
      new Promise(resolve => {
        resolveList = resolve;
      })
    );
    const { router, wrapper } = await mountAt(
      '/accounts/1/ai-agents?type=text'
    );

    expect(wrapper.find('[role="status"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('AI_AGENTS.EMPTY');
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents?type=text'
    );

    resolveList({ data: { agents: textList, text: { mode: 'byok' } } });
    await flushPromises();
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/3?type=text'
    );
    expect(wrapper.find('[role="status"]').exists()).toBe(false);
  });

  it('shows an error with a retry instead of redirecting when the list fails', async () => {
    aiAgentsAPI.get.mockRejectedValueOnce(new Error('network'));
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/ai-agents/3?type=text'
    );

    expect(wrapper.text()).toContain('AI_AGENTS.LOAD_ERROR');
    expect(replace).not.toHaveBeenCalled();
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/3?type=text'
    );
    const retry = wrapper
      .findAll('button')
      .find(button => button.text() === 'AI_AGENTS.RETRY');
    await retry.trigger('click');
    await flushPromises();
    expect(wrapper.find('[data-test="detail"]').text()).toBe('3');
  });
});

describe('navigation', () => {
  it('opens another assistant with push, keeping the type in the query', async () => {
    const { router, wrapper, push } = await mountAt(
      '/accounts/1/ai-agents?type=text'
    );

    await wrapper.findAll('nav a')[2].trigger('click');
    await flushPromises();

    expect(push).toHaveBeenCalled();
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/1?type=text'
    );
    expect(wrapper.find('nav a[aria-current="page"]').text()).toContain(
      'Agent 1'
    );
  });

  it('reloads the list when switching Text and Voice and opens the newest of that type', async () => {
    const { router, wrapper } = await mountAt(
      '/accounts/1/ai-agents?type=text'
    );
    expect(aiAgentsAPI.get).toHaveBeenCalledTimes(1);

    const voiceTab = wrapper
      .findAll('button[role="tab"]')
      .find(tab => tab.text() === 'AI_HUB.VOICE');
    await voiceTab.trigger('click');
    await flushPromises();

    expect(voiceAgentsAPI.get).toHaveBeenCalledTimes(1);
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/11?type=voice'
    );
    expect(listNames(wrapper)).toEqual(['Agent 11', 'Agent 10']);

    const textTab = wrapper
      .findAll('button[role="tab"]')
      .find(tab => tab.text() === 'AI_HUB.TEXT');
    await textTab.trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/ai-agents/3?type=text'
    );
  });
});

describe('account features', () => {
  it('falls back to the allowed type when the URL asks for a restricted one', async () => {
    const { router, wrapper } = await mountAt(
      '/accounts/2/ai-agents?type=text'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/2/ai-agents/11?type=voice'
    );
    expect(aiAgentsAPI.get).not.toHaveBeenCalled();
    expect(wrapper.findAll('button[role="tab"]')).toHaveLength(1);
  });

  it('shows the unavailable message and loads nothing without AI features', async () => {
    const { wrapper, replace } = await mountAt(
      '/accounts/3/ai-agents?type=text'
    );

    expect(wrapper.text()).toContain('AI_HUB.UNAVAILABLE');
    expect(aiAgentsAPI.get).not.toHaveBeenCalled();
    expect(voiceAgentsAPI.get).not.toHaveBeenCalled();
    expect(replace).not.toHaveBeenCalled();
  });
});
