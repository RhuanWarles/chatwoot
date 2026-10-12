import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { nextTick, ref } from 'vue';
import ToolExecutionDetailsDialog from './ToolExecutionDetailsDialog.vue';
import aiTools from 'dashboard/api/aiTools';

enableAutoUnmount(afterEach);

vi.mock('dashboard/api/aiTools', () => ({ default: { execution: vi.fn() } }));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: ref('pt-BR') }),
}));
vi.mock('dashboard/components-next/dialog/Dialog.vue', async () => {
  const { defineComponent, ref: vueRef } = await import('vue');
  return {
    default: defineComponent({
      props: ['title', 'cancelButtonLabel'],
      emits: ['close'],
      setup(props, { expose }) {
        const opened = vueRef(false);
        expose({
          open: () => {
            opened.value = true;
          },
        });
        return { opened };
      },
      template:
        '<div v-if="opened" role="dialog"><h3>{{ title }}</h3><slot /><button @click="$emit(\'close\')">{{ cancelButtonLabel }}</button></div>',
    }),
  };
});
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: {
    props: ['label'],
    template: '<button>{{ label }}</button>',
  },
}));

const execution = {
  id: 12,
  tool: { name: 'SendLink' },
  agent: { name: 'Larissa' },
  status: 'completed',
  response_status: 200,
  duration_ms: 166,
  created_at: '2026-10-12T06:22:40Z',
  execution_id: 'request-12',
  arguments: { secret: '***REDACTED***' },
};
beforeEach(() => {
  aiTools.execution.mockReset();
});

it('opens immediately with loading, then renders one scoped sanitized detail', async () => {
  let finish;
  aiTools.execution.mockImplementation(
    () =>
      new Promise(resolve => {
        finish = resolve;
      })
  );
  const dialog = mount(ToolExecutionDetailsDialog, {
    props: { executionId: 12, conversationId: 9 },
  });
  await nextTick();
  expect(dialog.find('[role="dialog"]').exists()).toBe(true);
  expect(dialog.find('[role="status"]').exists()).toBe(true);
  expect(aiTools.execution).toHaveBeenCalledWith(12, { conversation_id: 9 });
  finish({ data: { execution } });
  await flushPromises();
  expect(dialog.text()).toContain('SendLink');
  expect(dialog.text()).toContain('Larissa');
  expect(dialog.text()).toContain('166 ms');
  expect(dialog.text()).toContain('#9');
  expect(dialog.text()).toContain('request-12');
  expect(dialog.get('pre').text()).toContain('***REDACTED***');
  expect(dialog.text()).toContain('RESPONSE_NOT_STORED');
  await dialog.get('button').trigger('click');
  expect(dialog.emitted('close')).toHaveLength(1);
});

it('shows failed results without exposing internal request configuration', async () => {
  aiTools.execution.mockResolvedValue({
    data: {
      execution: {
        ...execution,
        status: 'failed',
        response_status: 500,
        error_code: 'tool_http_error',
      },
    },
  });
  const dialog = mount(ToolExecutionDetailsDialog, {
    props: { executionId: 12 },
  });
  await flushPromises();
  expect(aiTools.execution).toHaveBeenCalledWith(12, {});
  expect(dialog.text()).toContain('FAILED');
  expect(dialog.text()).toContain('500');
  expect(dialog.text()).toContain('tool_http_error');
  expect(dialog.text()).not.toContain('Authorization');
});

it('keeps the dialog open on a detail error and allows retry', async () => {
  aiTools.execution
    .mockRejectedValueOnce(new Error('private internal error'))
    .mockResolvedValueOnce({ data: { execution } });
  const dialog = mount(ToolExecutionDetailsDialog, {
    props: { executionId: 12 },
  });
  await flushPromises();
  expect(dialog.find('[role="dialog"]').exists()).toBe(true);
  expect(dialog.text()).toContain('DETAIL_ERROR');
  expect(dialog.text()).not.toContain('private internal error');
  await dialog.findAll('button')[0].trigger('click');
  await flushPromises();
  expect(dialog.text()).toContain('SendLink');
  expect(aiTools.execution).toHaveBeenCalledTimes(2);
});

it('loads a different execution and discards a stale response', async () => {
  let previous;
  aiTools.execution
    .mockImplementationOnce(
      () =>
        new Promise(resolve => {
          previous = resolve;
        })
    )
    .mockResolvedValueOnce({
      data: {
        execution: { ...execution, id: 13, tool: { name: 'OtherTool' } },
      },
    });
  const dialog = mount(ToolExecutionDetailsDialog, {
    props: { executionId: 12 },
  });
  await dialog.setProps({ executionId: 13 });
  await flushPromises();
  previous({ data: { execution } });
  await flushPromises();
  expect(dialog.text()).toContain('OtherTool');
  expect(dialog.text()).not.toContain('SendLink');
});
