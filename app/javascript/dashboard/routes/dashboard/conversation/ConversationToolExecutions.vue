<script setup>
import { computed, ref, watch } from 'vue';
import { useConversationToolExecutions } from 'dashboard/composables/useConversationToolExecutions';
import aiTools from 'dashboard/api/aiTools';
import ToolExecutionItem from './ToolExecutionItem.vue';

const { executions, loading, error, refresh, conversationId } =
  useConversationToolExecutions();
const expanded = ref(false);
const detail = ref(null);
const detailError = ref(false);
let selection = 0;
const visible = computed(() =>
  expanded.value ? executions.value : executions.value.slice(0, 5)
);
watch(conversationId, () => {
  selection += 1;
  expanded.value = false;
  detail.value = null;
  detailError.value = false;
});
const select = async execution => {
  const currentSelection = ++selection;
  detail.value = null;
  detailError.value = false;
  try {
    const { data } = await aiTools.execution(execution.id, {
      conversation_id: conversationId.value,
    });
    if (currentSelection === selection) detail.value = data.execution;
  } catch {
    if (currentSelection === selection) detailError.value = true;
  }
};
</script>

<template>
  <div class="p-2 min-w-0">
    <p v-if="error || detailError" class="text-xs text-n-ruby-11 p-2">
      {{ $t('CONVERSATION.TOOL_EXECUTIONS.ERROR') }}
    </p>
    <button v-if="error" class="text-xs text-n-blue-11 p-2" @click="refresh">
      {{ $t('CONVERSATION.TOOL_EXECUTIONS.RETRY') }}
    </button>
    <p
      v-else-if="loading && !executions.length"
      class="text-xs text-n-slate-11 p-2"
    >
      {{ $t('CONVERSATION.TOOL_EXECUTIONS.LOADING') }}
    </p>
    <p v-else-if="!executions.length" class="text-xs text-n-slate-11 p-2">
      {{ $t('CONVERSATION.TOOL_EXECUTIONS.EMPTY') }}
    </p>
    <div :class="expanded ? 'max-h-80 overflow-y-auto' : ''">
      <ToolExecutionItem
        v-for="execution in visible"
        :key="execution.id"
        :execution="execution"
        @select="select"
      />
    </div>
    <button
      v-if="executions.length > 5"
      class="text-xs text-n-blue-11 p-2"
      @click="expanded = !expanded"
    >
      {{
        expanded
          ? $t('CONVERSATION.TOOL_EXECUTIONS.LESS')
          : $t('CONVERSATION.TOOL_EXECUTIONS.ALL', { count: executions.length })
      }}
    </button>
    <div
      v-if="detail"
      class="mt-2 p-2 border-t border-n-weak text-xs text-n-slate-11 break-words"
    >
      <ToolExecutionItem :execution="detail" :interactive="false" />
      <dl class="space-y-2">
        <div>
          <dt>{{ $t('CONVERSATION.TOOL_EXECUTIONS.AGENT') }}</dt>
          <dd class="m-0">{{ detail.agent.name }}</dd>
        </div>
        <div>
          <dt>{{ $t('CONVERSATION.TOOL_EXECUTIONS.DATE') }}</dt>
          <dd class="m-0">
            {{
              new Date(detail.created_at).toLocaleString(
                $i18n.locale.replace('_', '-')
              )
            }}
          </dd>
        </div>
        <div>
          <dt>{{ $t('CONVERSATION.TOOL_EXECUTIONS.REQUEST_ID') }}</dt>
          <dd class="m-0 break-all">{{ detail.execution_id }}</dd>
        </div>
        <div>
          <dt>{{ $t('CONVERSATION.TOOL_EXECUTIONS.EXECUTION_ID') }}</dt>
          <dd class="m-0">{{ detail.id }}</dd>
        </div>
        <div v-if="detail.response_status">
          <dt>{{ $t('CONVERSATION.TOOL_EXECUTIONS.HTTP') }}</dt>
          <dd class="m-0">{{ detail.response_status }}</dd>
        </div>
        <div v-if="detail.error_code">
          <dt>{{ $t('CONVERSATION.TOOL_EXECUTIONS.ERROR_CODE') }}</dt>
          <dd class="m-0">{{ detail.error_code }}</dd>
        </div>
      </dl>
      <p class="mt-3 mb-1">
        {{ $t('CONVERSATION.TOOL_EXECUTIONS.ARGUMENTS') }}
      </p>
      <pre
        class="whitespace-pre-wrap break-all p-2 rounded bg-n-alpha-2 text-xs"
        >{{ JSON.stringify(detail.arguments, null, 2) }}</pre
      >
      <p class="text-xs">{{ $t('CONVERSATION.TOOL_EXECUTIONS.NOT_STORED') }}</p>
    </div>
  </div>
</template>
