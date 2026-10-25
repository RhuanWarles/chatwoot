<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import aiTools from 'dashboard/api/aiTools';

const props = defineProps({
  executionId: { type: Number, required: true },
  conversationId: { type: [Number, String], default: null },
});
const emit = defineEmits(['close']);
const { t, locale } = useI18n();
const dialog = ref(null);
const detail = ref(null);
const loading = ref(false);
const error = ref(false);
const attempt = ref(0);

watch(
  [() => props.executionId, () => props.conversationId, attempt],
  async (_, previous, onCleanup) => {
    let active = true;
    onCleanup(() => {
      active = false;
    });
    detail.value = null;
    error.value = false;
    loading.value = true;
    try {
      const params = props.conversationId
        ? { conversation_id: props.conversationId }
        : {};
      const { data } = await aiTools.execution(props.executionId, params);
      if (active) detail.value = data.execution;
    } catch {
      if (active) error.value = true;
    } finally {
      if (active) loading.value = false;
    }
  },
  { immediate: true }
);

const fields = computed(() => {
  if (!detail.value) return [];
  const item = detail.value;
  return [
    ['TOOL', item.tool.name],
    [
      'STATUS',
      t(
        item.status === 'completed'
          ? 'CONVERSATION.TOOL_EXECUTIONS.SUCCESS'
          : 'CONVERSATION.TOOL_EXECUTIONS.FAILED'
      ),
    ],
    ['AGENT', item.agent.name],
    [
      'DATE',
      new Date(item.created_at).toLocaleString(locale.value.replace('_', '-')),
    ],
    ['DURATION', `${item.duration_ms} ms`],
    ['HTTP', item.response_status],
    ['CONVERSATION', props.conversationId ? `#${props.conversationId}` : null],
    ['ERROR_CODE', item.error_code],
  ].filter(([, value]) => value !== null && value !== undefined);
});
const formattedResponse = computed(() => {
  const response = detail.value?.response;
  if (!response) return null;

  try {
    return JSON.stringify(JSON.parse(response), null, 2);
  } catch {
    return response;
  }
});
onMounted(() => dialog.value.open());
</script>

<template>
  <Dialog
    ref="dialog"
    width="2xl"
    :title="t('CONVERSATION.TOOL_EXECUTIONS.DETAIL_TITLE')"
    :cancel-button-label="t('CONVERSATION.TOOL_EXECUTIONS.CLOSE')"
    :show-confirm-button="false"
    @close="emit('close')"
  >
    <div class="max-h-96 overflow-y-auto min-w-0 text-sm">
      <p v-if="loading" role="status" class="text-n-slate-11">
        {{ t('CONVERSATION.TOOL_EXECUTIONS.LOADING') }}
      </p>
      <div v-else-if="error" role="alert">
        <p class="text-n-ruby-11">
          {{ t('CONVERSATION.TOOL_EXECUTIONS.DETAIL_ERROR') }}
        </p>
        <Button
          :label="t('CONVERSATION.TOOL_EXECUTIONS.RETRY')"
          variant="faded"
          type="button"
          @click="attempt += 1"
        />
      </div>
      <div v-else-if="detail" class="flex flex-col gap-5">
        <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4 m-0">
          <div v-for="[label, value] in fields" :key="label" class="min-w-0">
            <dt class="text-n-slate-11">
              {{ t(`CONVERSATION.TOOL_EXECUTIONS.${label}`) }}
            </dt>
            <dd class="m-0 break-words text-n-slate-12">{{ value }}</dd>
          </div>
        </dl>
        <details class="text-n-slate-11">
          <summary class="cursor-pointer">
            {{ t('CONVERSATION.TOOL_EXECUTIONS.TECHNICAL') }}
          </summary>
          <dl class="mt-3 space-y-3">
            <div>
              <dt>{{ t('CONVERSATION.TOOL_EXECUTIONS.REQUEST_ID') }}</dt>
              <dd class="m-0 break-all text-n-slate-12">
                {{ detail.execution_id }}
              </dd>
            </div>
            <div>
              <dt>{{ t('CONVERSATION.TOOL_EXECUTIONS.EXECUTION_ID') }}</dt>
              <dd class="m-0 text-n-slate-12">{{ detail.id }}</dd>
            </div>
          </dl>
        </details>
        <section class="min-w-0">
          <h4 class="text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION.TOOL_EXECUTIONS.SENT') }}
          </h4>
          <pre
            class="max-h-64 overflow-auto whitespace-pre-wrap break-all p-3 rounded-lg bg-n-alpha-2 font-mono text-xs text-n-slate-12"
            >{{ JSON.stringify(detail.arguments, null, 2) }}</pre
          >
        </section>
        <section v-if="formattedResponse" class="min-w-0">
          <h4 class="text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION.TOOL_EXECUTIONS.RESPONSE') }}
          </h4>
          <pre
            class="max-h-64 overflow-auto whitespace-pre-wrap break-all p-3 rounded-lg bg-n-alpha-2 font-mono text-xs text-n-slate-12"
            >{{ formattedResponse }}</pre
          >
        </section>
        <p v-else class="mb-0 text-xs text-n-slate-11">
          {{ t('CONVERSATION.TOOL_EXECUTIONS.RESPONSE_NOT_STORED') }}
        </p>
      </div>
    </div>
  </Dialog>
</template>
