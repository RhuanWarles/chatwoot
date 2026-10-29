<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import automationWorkflowsAPI from 'dashboard/api/automationWorkflows';
import { useWorkflowLookups } from '../useWorkflowLookups';
import { summarizeNode } from '../summaries';

const props = defineProps({
  workflowId: { type: [Number, String], default: null },
  nodes: { type: Array, default: () => [] },
});

const STATUS_TONES = {
  completed: 'bg-n-teal-3 text-n-teal-11',
  ok: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
  error: 'bg-n-ruby-3 text-n-ruby-11',
  running: 'bg-n-blue-3 text-n-blue-11',
  waiting: 'bg-n-amber-3 text-n-amber-11',
  skipped: 'bg-n-alpha-2 text-n-slate-11',
};

const { t } = useI18n();
const { lookups } = useWorkflowLookups();

const panelRef = ref(null);
const runs = ref([]);
const isLoading = ref(false);
const hasLoadError = ref(false);
const expandedId = ref(null);

const load = async () => {
  if (!props.workflowId) return;
  isLoading.value = true;
  hasLoadError.value = false;
  try {
    const { data } = await automationWorkflowsAPI.runs(props.workflowId);
    runs.value = Array.isArray(data) ? data : [];
  } catch {
    hasLoadError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const open = () => {
  expandedId.value = null;
  panelRef.value?.open();
  load();
};

const nodeLabel = nodeId => {
  const node = props.nodes.find(item => item.id === nodeId);
  if (!node) return nodeId;
  const { title, detail } = summarizeNode(node, lookups.value);
  return detail ? `${title}: ${detail}` : title;
};

const toggle = id => {
  expandedId.value = expandedId.value === id ? null : id;
};

const formatDate = value => (value ? new Date(value).toLocaleString() : '—');

defineExpose({ open });
</script>

<template>
  <SidePanel
    ref="panelRef"
    width="2xl"
    :title="t('AUTOMATION.WORKFLOWS.HISTORY.TITLE')"
    :description="t('AUTOMATION.WORKFLOWS.HISTORY.DESCRIPTION')"
  >
    <template #header-actions>
      <Button
        ghost
        slate
        sm
        icon="i-lucide-refresh-cw"
        :is-loading="isLoading"
        :aria-label="t('AUTOMATION.WORKFLOWS.HISTORY.REFRESH')"
        @click="load"
      />
    </template>
    <p v-if="hasLoadError" class="text-sm text-n-ruby-11">
      {{ t('AUTOMATION.WORKFLOWS.HISTORY.LOAD_ERROR') }}
    </p>
    <p v-else-if="!runs.length && !isLoading" class="text-sm text-n-slate-11">
      {{ t('AUTOMATION.WORKFLOWS.HISTORY.EMPTY') }}
    </p>
    <ul class="flex flex-col gap-2 p-0 m-0 list-none">
      <li
        v-for="run in runs"
        :key="run.id"
        class="rounded-lg outline outline-1 outline-n-weak"
      >
        <button
          type="button"
          class="flex items-center w-full gap-3 px-3 py-2.5 text-start"
          @click="toggle(run.id)"
        >
          <span
            class="px-2 py-0.5 text-xs rounded-md shrink-0"
            :class="STATUS_TONES[run.status]"
          >
            {{
              t(
                `AUTOMATION.WORKFLOWS.HISTORY.RUN_STATUS.${run.status.toUpperCase()}`
              )
            }}
          </span>
          <span class="flex-1 min-w-0 text-sm truncate text-n-slate-12">
            {{
              t(
                `AUTOMATION.WORKFLOWS.TRIGGERS.${String(run.trigger_event).toUpperCase()}`
              )
            }}
          </span>
          <span class="text-xs text-n-slate-10 shrink-0">
            {{ formatDate(run.started_at) }}
          </span>
        </button>
        <div
          v-if="expandedId === run.id"
          class="flex flex-col gap-2 px-3 pb-3 border-t border-n-weak"
        >
          <p v-if="run.error" class="mt-2 mb-0 text-xs text-n-ruby-11">
            {{ run.error }}
          </p>
          <p
            v-if="!run.trace?.length"
            class="mt-2 mb-0 text-xs text-n-slate-10"
          >
            {{ t('AUTOMATION.WORKFLOWS.HISTORY.NO_TRACE') }}
          </p>
          <ol class="flex flex-col gap-1.5 p-0 mt-2 mb-0 list-none">
            <li
              v-for="(step, index) in run.trace"
              :key="`${step.node_id}-${index}`"
              class="flex items-start gap-2 text-xs"
            >
              <span
                class="px-1.5 py-0.5 rounded-md shrink-0"
                :class="STATUS_TONES[step.status]"
              >
                {{
                  t(
                    `AUTOMATION.WORKFLOWS.HISTORY.STEP_STATUS.${String(step.status).toUpperCase()}`
                  )
                }}
              </span>
              <div class="flex flex-col min-w-0">
                <span class="text-n-slate-12 break-words">{{
                  nodeLabel(step.node_id)
                }}</span>
                <span v-if="step.error" class="text-n-ruby-11 break-words">{{
                  step.error
                }}</span>
              </div>
            </li>
          </ol>
        </div>
      </li>
    </ul>
  </SidePanel>
</template>
