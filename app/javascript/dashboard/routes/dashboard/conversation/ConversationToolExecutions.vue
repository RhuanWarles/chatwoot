<script setup>
import { computed, ref, watch } from 'vue';
import { useConversationToolExecutions } from 'dashboard/composables/useConversationToolExecutions';
import ToolExecutionItem from './ToolExecutionItem.vue';

const { executions, loading, error, refresh, conversationId, openExecution } =
  useConversationToolExecutions();
const expanded = ref(false);
const visible = computed(() =>
  expanded.value ? executions.value : executions.value.slice(0, 5)
);
watch(conversationId, () => {
  expanded.value = false;
});
const select = execution => openExecution(execution.id);
</script>

<template>
  <div class="p-2 min-w-0">
    <p v-if="error" class="text-xs text-n-ruby-11 p-2">
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
  </div>
</template>
