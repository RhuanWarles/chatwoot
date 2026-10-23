import { reactive } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import Playground from '../Playground.vue';
import aiAgentsAPI from 'dashboard/api/aiAgents';

const mocks = vi.hoisted(() => ({ route: null }));

vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values) => (values ? `${key}:${JSON.stringify(values)}` : key),
  }),
}));
vi.mock('dashboard/api/aiAgents', () => ({
  default: {
    show: vi.fn(),
    playgroundSession: vi.fn(),
    sendPlaygroundMessage: vi.fn(),
    clearPlaygroundSession: vi.fn(),
  },
}));

const mountPlayground = async messages => {
  mocks.route = reactive({ params: { agentId: '10' } });
  aiAgentsAPI.show.mockResolvedValue({
    data: { id: 10, name: 'Larissa', active: true, tools: [] },
  });
  aiAgentsAPI.playgroundSession.mockResolvedValue({
    data: {
      messages,
      runtime: { provider: 'OpenAI', model: 'gpt-4.1' },
      available_credits: 10,
    },
  });
  const wrapper = shallowMount(Playground, {
    global: { stubs: { RouterLink: true } },
  });
  await flushPromises();
  return wrapper;
};

beforeEach(() => {
  vi.clearAllMocks();
});

it('renders a real chat layout and keeps diagnostics out of the main message surface', async () => {
  const wrapper = await mountPlayground([
    { role: 'user', content: 'Olá', request_id: 'one' },
    {
      role: 'assistant',
      content: 'Como posso ajudar?',
      request_id: 'two',
      tool_calls: [
        {
          id: 'call-1',
          name: 'lookup',
          status: 'completed',
          duration_ms: 42,
          arguments: { q: 'x' },
        },
      ],
    },
  ]);

  expect(wrapper.findAll('article')).toHaveLength(2);
  expect(wrapper.find('article').classes()).toContain('self-end');
  expect(wrapper.findAll('details')).toHaveLength(1);
  expect(wrapper.text()).toContain('AI_PLAYGROUND.DIAGNOSTICS');
});

it('sends only non-empty messages through the existing playground API', async () => {
  const wrapper = await mountPlayground([]);
  aiAgentsAPI.sendPlaygroundMessage.mockResolvedValue({
    data: {
      message: { role: 'assistant', content: 'Resposta', request_id: 'two' },
    },
  });

  wrapper.vm.prompt = 'Teste';
  await wrapper.find('form').trigger('submit');
  await flushPromises();

  expect(aiAgentsAPI.sendPlaygroundMessage).toHaveBeenCalledWith(
    '10',
    expect.any(String),
    expect.objectContaining({ message: 'Teste' })
  );
  expect(wrapper.text()).toContain('Resposta');
});
