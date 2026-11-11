import { shallowMount } from '@vue/test-utils';
import ToolTestDialog from '../ToolTestDialog.vue';
import aiToolsAPI from 'dashboard/api/aiTools';

const mocks = vi.hoisted(() => ({ open: vi.fn() }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/aiTools', () => ({ default: { test: vi.fn() } }));

const mountDialog = (props = {}) =>
  shallowMount(ToolTestDialog, {
    props: {
      toolId: 12,
      agents: [
        { id: 7, name: 'Vendas' },
        { id: 8, name: 'Suporte' },
      ],
      ...props,
    },
    global: {
      renderStubDefaultSlot: true,
      stubs: {
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open: mocks.open, close: vi.fn() },
        },
      },
    },
  });

beforeEach(() => {
  vi.clearAllMocks();
  aiToolsAPI.test.mockResolvedValue({
    data: { status: 200, success: true, result: 'ok', duration_ms: 34 },
  });
});

it('opens with the first agent selected and runs the test with the typed arguments', async () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  expect(mocks.open).toHaveBeenCalled();
  expect(wrapper.vm.testAgentId).toBe(7);

  wrapper.vm.testArguments = '{"order_id":"42"}';
  await wrapper.vm.runTest();

  expect(aiToolsAPI.test).toHaveBeenCalledWith(12, 7, { order_id: '42' }, null);
  expect(wrapper.vm.testResult.result).toBe('ok');
});

it('sends the conversation id when one is typed', async () => {
  const wrapper = mountDialog({ hasContextParameters: true });
  wrapper.vm.open();
  wrapper.vm.testConversationId = '55';

  await wrapper.vm.runTest();

  expect(aiToolsAPI.test).toHaveBeenCalledWith(12, 7, {}, '55');
});

it('does not call the API when the arguments are not valid JSON', async () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  wrapper.vm.testArguments = '{invalid';

  await wrapper.vm.runTest();

  expect(aiToolsAPI.test).not.toHaveBeenCalled();
  expect(wrapper.vm.error).toBe('AI_TOOLS.JSON_INVALID');
});

it('explains a missing conversation and any other failure', async () => {
  const wrapper = mountDialog();
  wrapper.vm.open();

  aiToolsAPI.test.mockRejectedValueOnce({ response: { status: 404 } });
  await wrapper.vm.runTest();
  expect(wrapper.vm.error).toBe('AI_TOOLS.TEST_NOT_FOUND');

  aiToolsAPI.test.mockRejectedValueOnce(new Error('network'));
  await wrapper.vm.runTest();
  expect(wrapper.vm.error).toBe('AI_TOOLS.TEST_ERROR');
});

it('warns that the test runs the saved version when there are unsaved edits', () => {
  expect(mountDialog().text()).not.toContain('AI_TOOLS.TEST_UNSAVED_NOTE');
  expect(mountDialog({ unsaved: true }).text()).toContain(
    'AI_TOOLS.TEST_UNSAVED_NOTE'
  );
});

it('clears the previous result every time it is opened', async () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  await wrapper.vm.runTest();
  expect(wrapper.vm.testResult).not.toBe(null);

  wrapper.vm.open();
  expect(wrapper.vm.testResult).toBe(null);
});
