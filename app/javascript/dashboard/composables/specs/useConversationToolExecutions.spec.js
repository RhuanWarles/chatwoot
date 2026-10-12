import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import { provideConversationToolExecutions } from '../useConversationToolExecutions';
import aiTools from 'dashboard/api/aiTools';

const chat = ref({ id: 9, messages: [] });
const account = ref(1);
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => (key === 'getSelectedChat' ? chat : account),
}));
vi.mock('dashboard/api/aiTools', () => ({ default: { executions: vi.fn() } }));

beforeEach(() => {
  chat.value = { id: 9, messages: [] };
  aiTools.executions.mockReset();
});

it('shares paginated executions and refreshes on existing message events', async () => {
  aiTools.executions
    .mockResolvedValueOnce({
      data: { executions: [{ id: 1 }], meta: { total_count: 2 } },
    })
    .mockResolvedValueOnce({
      data: { executions: [{ id: 2 }], meta: { total_count: 2 } },
    });
  let state;
  const wrapper = mount({
    setup() {
      state = provideConversationToolExecutions();
      return () => null;
    },
  });
  await flushPromises();
  expect(state.executions.value).toEqual([{ id: 1 }, { id: 2 }]);
  expect(aiTools.executions).toHaveBeenNthCalledWith(2, {
    conversation_id: 9,
    page: 2,
  });
  aiTools.executions.mockResolvedValue({
    data: { executions: [{ id: 3 }], meta: { total_count: 1 } },
  });
  chat.value.messages.push({ id: 99 });
  await flushPromises();
  expect(state.executions.value).toEqual([{ id: 3 }]);
  wrapper.unmount();
});

it('rejects stale responses after switching conversations', async () => {
  let resolvePrevious;
  aiTools.executions
    .mockImplementationOnce(
      () =>
        new Promise(resolve => {
          resolvePrevious = resolve;
        })
    )
    .mockResolvedValueOnce({
      data: { executions: [{ id: 10 }], meta: { total_count: 1 } },
    });
  let state;
  const wrapper = mount({
    setup() {
      state = provideConversationToolExecutions();
      return () => null;
    },
  });
  chat.value = { id: 10, messages: [] };
  await flushPromises();
  resolvePrevious({
    data: { executions: [{ id: 9 }], meta: { total_count: 1 } },
  });
  await flushPromises();
  expect(state.executions.value).toEqual([{ id: 10 }]);
  wrapper.unmount();
});
