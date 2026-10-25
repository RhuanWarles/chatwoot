import { reactive } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import AgentEditorPage from '../AgentEditorPage.vue';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import knowledgeAPI from 'dashboard/api/knowledgeBases';
import { pipelinesAPI } from 'dashboard/api/crm';

const mocks = vi.hoisted(() => ({
  route: null,
  push: vi.fn(),
  dispatch: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
  useRouter: () => ({ push: mocks.push }),
}));
vi.mock('vuex', () => ({
  useStore: () => ({
    getters: { 'inboxes/getInboxes': [{ id: 1, name: 'Support' }] },
    dispatch: mocks.dispatch,
  }),
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));
vi.mock('dashboard/api/aiAgents', () => ({
  default: {
    get: vi.fn(),
    tools: vi.fn(),
    show: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
  },
}));
vi.mock('dashboard/api/knowledgeBases', () => ({
  default: { get: vi.fn() },
}));
vi.mock('dashboard/api/crm', () => ({
  pipelinesAPI: { get: vi.fn() },
}));

const mountEditor = async (agentId = null, agentData = null) => {
  mocks.route = reactive({ params: agentId ? { agentId } : {}, query: {} });
  mocks.dispatch.mockResolvedValue(true);
  aiAgentsAPI.get.mockResolvedValue({
    data: { agents: [], providers: ['openai'], text: { mode: 'byok' } },
  });
  aiAgentsAPI.tools.mockResolvedValue({ data: { tools: [] } });
  knowledgeAPI.get.mockResolvedValue({ data: { bases: [] } });
  pipelinesAPI.get.mockResolvedValue({ data: [] });
  aiAgentsAPI.show.mockResolvedValue({ data: agentData });
  const wrapper = shallowMount(AgentEditorPage, {
    global: { stubs: { RouterLink: true } },
  });
  await flushPromises();
  return wrapper;
};

beforeEach(() => {
  vi.clearAllMocks();
});

it('organizes the editor into four tabs without losing the draft between tabs', async () => {
  const wrapper = await mountEditor();
  const tabs = wrapper.findAll('nav button');

  expect(tabs).toHaveLength(4);
  expect(wrapper.find('section').text()).toContain('AI_AGENTS.TABS.GENERAL');

  await tabs[1].trigger('click');
  expect(wrapper.find('section').text()).toContain('AI_AGENTS.PROMPT_SECTION');
  await tabs[2].trigger('click');
  expect(wrapper.find('section').text()).toContain('AI_AGENTS.AUDIO_ENABLED');
  expect(wrapper.vm.draft.audio_enabled).toBe(false);
  await tabs[3].trigger('click');
  expect(wrapper.find('section').text()).toContain(
    'AI_AGENTS.CONNECTIONS_SECTION'
  );
  expect(wrapper.vm.draft.inbox_ids).toEqual([]);
});

it('keeps the existing save payload contract while showing unsaved state', async () => {
  const wrapper = await mountEditor();
  wrapper.vm.draft.name = 'Support assistant';
  await wrapper.vm.$nextTick();

  expect(wrapper.text()).toContain('AI_AGENTS.UNSAVED');
  expect(wrapper.find('header').exists()).toBe(true);
  expect(wrapper.vm.draft.name).toBe('Support assistant');
});

it('loads the persisted timezone when editing an agent', async () => {
  const wrapper = await mountEditor('3', {
    id: 3,
    name: 'Support assistant',
    description: null,
    provider: 'openai',
    model: 'model',
    system_prompt: 'Help customers',
    timezone: 'Europe/Lisbon',
    inboxes: [],
  });

  expect(wrapper.vm.draft.timezone).toBe('Europe/Lisbon');
});
