<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { ACTIONS, ACTION_GROUPS } from '../actions';
import {
  NODE_ICONS,
  NODE_TYPES,
  TRIGGER_EVENTS,
  actionLabelKey,
  triggerLabelKey,
} from '../constants';
import { DRAG_MIME } from '../workflowContext';

const emit = defineEmits(['add']);

const { t } = useI18n();

const logic = [
  { type: NODE_TYPES.CONDITION, icon: NODE_ICONS.condition },
  { type: NODE_TYPES.SWITCH, icon: NODE_ICONS.switch },
  { type: NODE_TYPES.WAIT, icon: NODE_ICONS.wait },
];

const sections = computed(() => [
  {
    key: 'triggers',
    title: t('AUTOMATION.WORKFLOWS.PALETTE.TRIGGERS'),
    items: TRIGGER_EVENTS.map(item => ({
      id: item.key,
      type: NODE_TYPES.TRIGGER,
      preset: { event: item.key },
      icon: item.icon,
      label: t(triggerLabelKey(item.key)),
    })),
  },
  {
    key: 'logic',
    title: t('AUTOMATION.WORKFLOWS.PALETTE.LOGIC'),
    items: logic.map(item => ({
      id: item.type,
      type: item.type,
      preset: {},
      icon: item.icon,
      label: t(`AUTOMATION.WORKFLOWS.NODE_TYPES.${item.type.toUpperCase()}`),
    })),
  },
  ...ACTION_GROUPS.map(group => ({
    key: group,
    title: t(`AUTOMATION.WORKFLOWS.ACTION_GROUPS.${group.toUpperCase()}`),
    items: ACTIONS.filter(action => action.group === group).map(action => ({
      id: action.key,
      type: NODE_TYPES.ACTION,
      preset: { action: action.key },
      icon: action.icon,
      label: t(actionLabelKey(action.key)),
    })),
  })),
]);

const startDrag = (event, item) => {
  event.dataTransfer.setData(
    DRAG_MIME,
    JSON.stringify({ type: item.type, preset: item.preset })
  );
  event.dataTransfer.effectAllowed = 'move';
};
</script>

<template>
  <aside
    class="flex flex-col w-64 shrink-0 h-full overflow-y-auto border-e border-n-weak bg-n-solid-1"
  >
    <div class="px-4 py-3 border-b border-n-weak">
      <h3 class="mb-0 text-sm font-medium text-n-slate-12">
        {{ t('AUTOMATION.WORKFLOWS.PALETTE.TITLE') }}
      </h3>
      <p class="mt-1 mb-0 text-xs text-n-slate-10">
        {{ t('AUTOMATION.WORKFLOWS.PALETTE.HINT') }}
      </p>
    </div>
    <details
      v-for="(section, index) in sections"
      :key="section.key"
      :open="index > 0 && index < 4"
      class="border-b border-n-weak group"
    >
      <summary
        class="flex items-center justify-between px-4 py-2.5 text-xs font-medium uppercase cursor-pointer select-none text-n-slate-11 hover:text-n-slate-12"
      >
        {{ section.title }}
        <Icon
          icon="i-lucide-chevron-down"
          class="size-3.5 transition-transform group-open:rotate-180"
        />
      </summary>
      <div class="flex flex-col gap-1 px-2 pb-2">
        <button
          v-for="item in section.items"
          :key="item.id"
          type="button"
          draggable="true"
          class="flex items-center gap-2 px-2 py-1.5 text-sm text-start rounded-lg cursor-grab text-n-slate-12 hover:bg-n-alpha-2"
          @dragstart="startDrag($event, item)"
          @click="emit('add', item.type, item.preset)"
        >
          <Icon :icon="item.icon" class="size-4 shrink-0 text-n-slate-11" />
          <span class="truncate">{{ item.label }}</span>
        </button>
      </div>
    </details>
  </aside>
</template>
