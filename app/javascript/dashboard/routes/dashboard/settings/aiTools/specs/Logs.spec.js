import { flushPromises, shallowMount } from '@vue/test-utils';
import Logs from '../Logs.vue';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import aiToolsAPI from 'dashboard/api/aiTools';

vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/aiAgents', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/aiTools', () => ({
  default: { get: vi.fn(), executions: vi.fn() },
}));

beforeEach(() => {
  vi.clearAllMocks();
  aiAgentsAPI.get.mockResolvedValue({ data: { agents: [] } });
  aiToolsAPI.get.mockResolvedValue({ data: { tools: [] } });
  aiToolsAPI.executions.mockResolvedValue({
    data: { executions: [], meta: { total_count: 0 } },
  });
});

it('lists every tool as a page of its own, with the header and the tool filter', async () => {
  const wrapper = shallowMount(Logs);
  await flushPromises();

  expect(wrapper.find('header').exists()).toBe(true);
  expect(wrapper.find('select[aria-label="AI_TOOLS.LOGS_TOOL"]').exists()).toBe(
    true
  );
  expect(aiToolsAPI.get).toHaveBeenCalled();
  expect(aiToolsAPI.executions).toHaveBeenCalledWith(
    expect.objectContaining({ ai_tool_id: '' })
  );
});

it('limits the logs to one tool when embedded in its detail', async () => {
  const wrapper = shallowMount(Logs, { props: { toolId: 12 } });
  await flushPromises();

  expect(wrapper.find('header').exists()).toBe(false);
  expect(wrapper.find('select[aria-label="AI_TOOLS.LOGS_TOOL"]').exists()).toBe(
    false
  );
  expect(aiToolsAPI.get).not.toHaveBeenCalled();
  expect(aiToolsAPI.executions).toHaveBeenCalledWith(
    expect.objectContaining({ ai_tool_id: 12, page: 1 })
  );
});
