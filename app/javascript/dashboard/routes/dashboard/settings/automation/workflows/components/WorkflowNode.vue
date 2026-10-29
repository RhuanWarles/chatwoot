<script setup>
import { computed, inject, nextTick, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { Handle, Position, useVueFlow } from '@vue-flow/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useWorkflowLookups } from '../useWorkflowLookups';
import { NODE_CATEGORY, NODE_TYPES, nodeIcon } from '../constants';
import { hasInput, outputHandles } from '../graph';
import { caseLabel, summarizeNode } from '../summaries';
import { HANDLE_TONES, NODE_ISSUES_KEY, NODE_TONES } from '../workflowContext';

const props = defineProps({
  id: { type: String, required: true },
  type: { type: String, required: true },
  data: { type: Object, required: true },
  selected: { type: Boolean, default: false },
});

const { t } = useI18n();
const { lookups } = useWorkflowLookups();
const issuesByNode = inject(
  NODE_ISSUES_KEY,
  computed(() => ({}))
);

const node = computed(() => ({ type: props.type, data: props.data }));
const summary = computed(() => summarizeNode(node.value, lookups.value));
const tone = computed(() => NODE_TONES[NODE_CATEGORY[props.type]]);
const icon = computed(() => nodeIcon(node.value));
const handles = computed(() => outputHandles(node.value));
const isBranching = computed(
  () => props.type === NODE_TYPES.CONDITION || props.type === NODE_TYPES.SWITCH
);
const issues = computed(() => issuesByNode.value[props.id] || []);

// Switch cases add and remove handles after mount; Vue Flow has to measure them again.
const { updateNodeInternals } = useVueFlow();
watch(
  () => handles.value.map(handle => handle.id).join(),
  () => nextTick(() => updateNodeInternals([props.id]))
);

const handleLabel = handle => {
  if (props.type === NODE_TYPES.SWITCH && handle.id !== 'default') {
    return caseLabel(
      props.data,
      { value: handle.caseValue, label: handle.label },
      lookups.value
    );
  }
  return t(`AUTOMATION.WORKFLOWS.HANDLES.${handle.id.toUpperCase()}`);
};
</script>

<template>
  <div
    class="w-64 rounded-xl shadow-sm cursor-grab bg-n-solid-2 outline outline-1 -outline-offset-1"
    :class="[
      selected ? 'outline-2 outline-n-brand' : 'outline-n-weak',
      issues.length && !selected ? 'outline-n-ruby-8' : '',
    ]"
  >
    <Handle
      v-if="hasInput({ type })"
      type="target"
      :position="Position.Left"
      class="!w-3 !h-3 !-left-1.5 !border-2 !border-n-solid-2 !bg-n-slate-9"
    />
    <div
      class="flex items-center gap-2 px-3 py-2 text-xs font-medium rounded-t-xl"
      :class="tone.header"
    >
      <Icon :icon="icon" class="size-4 shrink-0" />
      <span class="truncate">{{ summary.title }}</span>
      <Icon
        v-if="issues.length"
        v-tooltip.top="t('AUTOMATION.WORKFLOWS.VALIDATION.NODE_HAS_ISSUES')"
        icon="i-lucide-triangle-alert"
        class="ms-auto size-4 shrink-0 text-n-ruby-10"
      />
    </div>
    <p
      class="px-3 py-2.5 mb-0 text-sm text-n-slate-12 line-clamp-2 break-words"
    >
      {{ summary.detail || t('AUTOMATION.WORKFLOWS.SUMMARY.NOT_CONFIGURED') }}
    </p>
    <template v-if="isBranching">
      <div class="pb-1 border-t border-n-weak">
        <div
          v-for="handle in handles"
          :key="handle.id"
          class="relative flex items-center justify-end px-3 py-1.5 text-xs text-n-slate-11"
        >
          <span class="truncate">{{ handleLabel(handle) }}</span>
          <Handle
            :id="handle.id"
            type="source"
            :position="Position.Right"
            class="!w-3 !h-3 !-right-1.5 !border-2 !border-n-solid-2"
            :class="HANDLE_TONES[handle.tone]"
          />
        </div>
      </div>
    </template>
    <Handle
      v-else
      id="out"
      type="source"
      :position="Position.Right"
      class="!w-3 !h-3 !-right-1.5 !border-2 !border-n-solid-2 !bg-n-blue-9"
    />
  </div>
</template>
