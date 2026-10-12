import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import ConversationToolExecutions from '../ConversationToolExecutions.vue';
import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import aiTools from 'dashboard/api/aiTools';

vi.mock('dashboard/api/aiTools', () => ({ default: { execution: vi.fn() } }));
vi.mock('shared/components/EmojiOrIcon.vue', () => ({
  default: { template: '<span />' },
}));
const state = {
  executions: ref([]),
  loading: ref(false),
  error: ref(false),
  refresh: vi.fn(),
  openExecution: vi.fn(),
  conversationId: ref(9),
};
vi.mock('dashboard/composables/useConversationToolExecutions', () => ({
  useConversationToolExecutions: () => state,
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ locale: ref('pt-BR') }) }));

const execution = {
  id: 1,
  tool: { name: 'SendLink' },
  agent: { name: 'Larissa' },
  status: 'completed',
  duration_ms: 42,
  created_at: '2026-10-12T12:00:00Z',
  execution_id: 'request-1',
  arguments: { phone: '***REDACTED***' },
  response_status: 200,
};
const options = {
  global: {
    mocks: { $t: key => key, $i18n: { locale: 'pt-BR' } },
    stubs: { EmojiOrIcon: true, 'fluent-icon': true },
  },
};

beforeEach(() => {
  state.executions.value = [];
  state.conversationId.value = 9;
  state.error.value = false;
  aiTools.execution.mockReset();
  state.openExecution.mockReset();
});

it('shows an empty state and reuses the accordion expand/collapse design', async () => {
  const panel = mount(ConversationToolExecutions, options);
  expect(panel.text()).toContain('TOOL_EXECUTIONS.EMPTY');
  const accordion = mount(AccordionItem, {
    ...options,
    props: { title: 'Tools', isOpen: false },
    slots: { default: 'content' },
  });
  expect(accordion.text()).not.toContain('content');
  await accordion.get('button').trigger('click');
  expect(accordion.emitted('toggle')).toHaveLength(1);
  await accordion.setProps({ isOpen: true });
  expect(accordion.text()).toContain('content');
  expect(accordion.get('button').classes()).toContain('outline-n-weak');
});

it('opens shared details without expanding them in the sidebar', async () => {
  state.executions.value = Array.from({ length: 6 }, (_, index) => ({
    ...execution,
    id: index + 1,
  }));
  aiTools.execution.mockResolvedValue({ data: { execution } });
  const panel = mount(ConversationToolExecutions, options);
  expect(panel.findAll('button')).toHaveLength(6);
  expect(panel.text()).toContain('42 ms');
  await panel.findAll('button')[5].trigger('click');
  expect(panel.findAll('button')).toHaveLength(7);
  await panel.findAll('button')[0].trigger('click');
  await flushPromises();
  expect(state.openExecution).toHaveBeenCalledWith(1);
  expect(aiTools.execution).not.toHaveBeenCalled();
  expect(panel.find('pre').exists()).toBe(false);
  expect(panel.text()).not.toContain('request-1');
});

it('renders failed executions and clears details when switching conversation', async () => {
  state.executions.value = [
    { ...execution, status: 'failed', response_status: 500 },
  ];
  aiTools.execution.mockResolvedValue({ data: { execution } });
  const panel = mount(ConversationToolExecutions, options);
  expect(panel.text()).toContain('FAILED');
  expect(panel.text()).toContain('HTTP 500');
  await panel.get('button').trigger('click');
  await flushPromises();
  state.executions.value = [];
  state.conversationId.value = 10;
  await flushPromises();
  expect(panel.text()).not.toContain('SendLink');
  expect(panel.text()).not.toContain('request-1');
});
