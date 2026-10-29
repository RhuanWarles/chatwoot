<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { BaseTableCell, BaseTableRow } from 'dashboard/components-next/table';
import { triggerLabelKey } from '../constants';

const props = defineProps({
  workflow: { type: Object, required: true },
});

const emit = defineEmits(['toggle', 'edit', 'duplicate', 'delete']);

const RUN_TONES = {
  completed: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
  running: 'bg-n-blue-3 text-n-blue-11',
  waiting: 'bg-n-amber-3 text-n-amber-11',
};

const EMPTY_VALUE = '—';

const { t } = useI18n();

const triggers = computed(() =>
  (props.workflow.trigger_events || [])
    .map(event => t(triggerLabelKey(event)))
    .join(', ')
);
const lastRun = computed(() => props.workflow.last_run);
const lastRunDate = computed(() =>
  lastRun.value?.started_at
    ? new Date(lastRun.value.started_at).toLocaleString()
    : ''
);
</script>

<template>
  <BaseTableRow :item="workflow">
    <template #default>
      <BaseTableCell class="max-w-0 w-full">
        <div class="flex flex-col min-w-0">
          <button
            type="button"
            class="text-start text-body-main text-n-slate-12 truncate hover:underline"
            @click="emit('edit', workflow)"
          >
            {{ workflow.name }}
          </button>
          <span
            v-if="workflow.description"
            class="text-body-main text-n-slate-11 truncate"
          >
            {{ workflow.description }}
          </span>
        </div>
      </BaseTableCell>
      <BaseTableCell>
        <span class="text-body-main text-n-slate-11">
          {{ triggers || EMPTY_VALUE }}
        </span>
      </BaseTableCell>
      <BaseTableCell>
        <div v-if="lastRun" class="flex flex-col gap-1">
          <span
            class="px-2 py-0.5 text-xs rounded-md w-fit"
            :class="RUN_TONES[lastRun.status]"
          >
            {{
              t(
                `AUTOMATION.WORKFLOWS.HISTORY.RUN_STATUS.${lastRun.status.toUpperCase()}`
              )
            }}
          </span>
          <span class="text-xs text-n-slate-10 whitespace-nowrap">
            {{ lastRunDate }}
          </span>
        </div>
        <span v-else class="text-body-main text-n-slate-10">{{
          EMPTY_VALUE
        }}</span>
      </BaseTableCell>
      <BaseTableCell>
        <ToggleSwitch
          :model-value="workflow.active"
          @update:model-value="emit('toggle', workflow)"
        />
      </BaseTableCell>
      <BaseTableCell align="end">
        <div class="flex justify-end gap-3 shrink-0">
          <Button
            v-tooltip.top="t('AUTOMATION.WORKFLOWS.LIST.EDIT')"
            icon="i-woot-edit-pen"
            slate
            sm
            @click="emit('edit', workflow)"
          />
          <Button
            v-tooltip.top="t('AUTOMATION.WORKFLOWS.LIST.DUPLICATE')"
            icon="i-woot-clone"
            slate
            sm
            @click="emit('duplicate', workflow)"
          />
          <Button
            v-tooltip.top="t('AUTOMATION.WORKFLOWS.LIST.DELETE')"
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            @click="emit('delete', workflow)"
          />
        </div>
      </BaseTableCell>
    </template>
  </BaseTableRow>
</template>
