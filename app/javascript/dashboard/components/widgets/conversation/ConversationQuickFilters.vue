<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  agents: { type: Array, default: () => [] },
  inboxes: { type: Array, default: () => [] },
  labels: { type: Array, default: () => [] },
  aiAgentId: { type: [String, Number], default: null },
  inboxId: { type: [String, Number], default: null },
  label: { type: String, default: null },
  aiState: { type: String, default: null },
});

const emit = defineEmits(['change']);
const { t } = useI18n();

const allOption = computed(() => ({
  value: '',
  label: t('CHAT_LIST.QUICK_FILTERS.ALL'),
}));

const agentOptions = computed(() => [
  allOption.value,
  ...props.agents.map(agent => ({ value: agent.id, label: agent.name })),
]);

const inboxOptions = computed(() => [
  allOption.value,
  ...props.inboxes.map(inbox => ({ value: inbox.id, label: inbox.name })),
]);

const labelOptions = computed(() => [
  allOption.value,
  ...props.labels.map(label => ({ value: label.title, label: label.title })),
]);

const aiStateOptions = computed(() => [
  allOption.value,
  {
    value: 'active',
    label: t('CHAT_LIST.QUICK_FILTERS.AI_ACTIVE'),
  },
  {
    value: 'inactive',
    label: t('CHAT_LIST.QUICK_FILTERS.AI_INACTIVE'),
  },
]);

const filterChange = (key, value) => {
  emit('change', {
    aiAgentId: props.aiAgentId,
    inboxId: props.inboxId,
    label: props.label,
    aiState: props.aiState,
    [key]: value || null,
  });
};
</script>

<template>
  <div
    class="grid grid-cols-2 gap-2 px-3 pb-3 border-b border-n-weak md:grid-cols-4"
  >
    <label class="min-w-0 text-xs text-n-slate-11">
      <span class="block mb-1">
        {{ $t('CHAT_LIST.QUICK_FILTERS.ASSISTANT') }}
      </span>
      <ComboBox
        :model-value="aiAgentId || ''"
        :options="agentOptions"
        :placeholder="$t('CHAT_LIST.QUICK_FILTERS.ALL')"
        :search-placeholder="$t('CHAT_LIST.QUICK_FILTERS.SEARCH_ASSISTANT')"
        @update:model-value="filterChange('aiAgentId', $event)"
      />
    </label>

    <label class="min-w-0 text-xs text-n-slate-11">
      <span class="block mb-1">{{ $t('CHAT_LIST.QUICK_FILTERS.INBOX') }}</span>
      <ComboBox
        :model-value="inboxId || ''"
        :options="inboxOptions"
        :placeholder="$t('CHAT_LIST.QUICK_FILTERS.ALL')"
        :search-placeholder="$t('CHAT_LIST.QUICK_FILTERS.SEARCH_INBOX')"
        @update:model-value="filterChange('inboxId', $event)"
      />
    </label>

    <label class="min-w-0 text-xs text-n-slate-11">
      <span class="block mb-1">{{ $t('CHAT_LIST.QUICK_FILTERS.TAG') }}</span>
      <ComboBox
        :model-value="label || ''"
        :options="labelOptions"
        :placeholder="$t('CHAT_LIST.QUICK_FILTERS.ALL')"
        :search-placeholder="$t('CHAT_LIST.QUICK_FILTERS.SEARCH_TAG')"
        @update:model-value="filterChange('label', $event)"
      />
    </label>

    <label class="min-w-0 text-xs text-n-slate-11">
      <span class="block mb-1">
        {{ $t('CHAT_LIST.QUICK_FILTERS.AI_STATE') }}
      </span>
      <ComboBox
        :model-value="aiState || ''"
        :options="aiStateOptions"
        :placeholder="$t('CHAT_LIST.QUICK_FILTERS.ALL')"
        :search-placeholder="$t('CHAT_LIST.QUICK_FILTERS.SEARCH_AI_STATE')"
        @update:model-value="filterChange('aiState', $event)"
      />
    </label>
  </div>
</template>
