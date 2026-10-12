<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  execution: { type: Object, required: true },
  interactive: { type: Boolean, default: true },
});
defineEmits(['select']);
const { locale } = useI18n();
const time = computed(() =>
  new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(props.execution.created_at))
);
</script>

<template>
  <component
    :is="interactive ? 'button' : 'div'"
    class="w-full min-w-0 m-0 p-2 text-start rounded-lg"
    :class="{ 'hover:bg-n-alpha-2': interactive }"
    @click="interactive && $emit('select', execution)"
  >
    <span class="block text-sm font-medium text-n-slate-12 break-words">{{
      execution.tool.name
    }}</span>
    <span
      class="text-xs"
      :class="
        execution.status === 'completed' ? 'text-n-teal-11' : 'text-n-ruby-11'
      "
    >
      {{
        $t(
          execution.status === 'completed'
            ? 'CONVERSATION.TOOL_EXECUTIONS.SUCCESS'
            : 'CONVERSATION.TOOL_EXECUTIONS.FAILED'
        )
      }}
    </span>
    <span class="text-xs text-n-slate-11">
      · {{ execution.duration_ms }} ms · {{ time }}</span
    >
    <span
      v-if="execution.status === 'failed'"
      class="block text-xs text-n-slate-11 break-words"
    >
      {{
        execution.response_status
          ? `HTTP ${execution.response_status}`
          : execution.error_code
      }}
    </span>
  </component>
</template>
