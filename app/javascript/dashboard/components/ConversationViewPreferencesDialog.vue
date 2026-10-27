<script setup>
import { ref, watch } from 'vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import { useI18n } from 'vue-i18n';
import { normalizeConversationViewPreferences } from 'dashboard/helper/conversationViewPreferences';

const props = defineProps({
  preferences: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['save', 'close']);
const dialogRef = ref(null);
const draft = ref(normalizeConversationViewPreferences(props.preferences));
const { t } = useI18n();

watch(
  () => props.preferences,
  value => {
    draft.value = normalizeConversationViewPreferences(value);
  },
  { deep: true }
);

const open = () => dialogRef.value?.open();
const close = () => {
  emit('close');
  dialogRef.value?.close();
};
const save = () => {
  emit('save', normalizeConversationViewPreferences(draft.value));
  dialogRef.value?.close();
};

defineExpose({ open, close });

const tabItems = ['me', 'unassigned', 'all', 'unanswered'];
const filterItems = ['assistant', 'inbox', 'tag', 'ai'];

const isOnlyVisibleTab = key =>
  draft.value.tabs[key] &&
  Object.entries(draft.value.tabs).every(
    ([tabKey, visible]) => tabKey === key || !visible
  );

const isOnlyVisibleFilter = key =>
  draft.value.filters[key] &&
  Object.entries(draft.value.filters).every(
    ([filterKey, visible]) => filterKey === key || !visible
  );
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CHAT_LIST.VIEW_PREFERENCES.TITLE')"
    :description="t('CHAT_LIST.VIEW_PREFERENCES.DESCRIPTION')"
    :confirm-button-label="t('CHAT_LIST.VIEW_PREFERENCES.SAVE')"
    width="sm"
    @confirm="save"
    @close="emit('close')"
  >
    <div class="grid gap-6">
      <section class="grid gap-3">
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t('CHAT_LIST.VIEW_PREFERENCES.TABS') }}
        </h4>
        <label
          v-for="key in tabItems"
          :key="`tab-${key}`"
          class="flex items-center gap-3 text-sm text-n-slate-11"
        >
          <Checkbox
            v-model="draft.tabs[key]"
            :disabled="isOnlyVisibleTab(key)"
          />
          {{ t(`CHAT_LIST.ASSIGNEE_TYPE_TABS.${key}`) }}
        </label>
      </section>
      <section class="grid gap-3">
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t('CHAT_LIST.VIEW_PREFERENCES.FILTERS') }}
        </h4>
        <label
          v-for="key in filterItems"
          :key="`filter-${key}`"
          class="flex items-center gap-3 text-sm text-n-slate-11"
        >
          <Checkbox
            v-model="draft.filters[key]"
            :disabled="isOnlyVisibleFilter(key)"
          />
          {{ t(`CHAT_LIST.VIEW_PREFERENCES.FILTER_NAMES.${key}`) }}
        </label>
      </section>
    </div>
  </Dialog>
</template>
