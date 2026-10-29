<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import automationWorkflowsAPI from 'dashboard/api/automationWorkflows';
import { dealsAPI } from 'dashboard/api/crm';
import InspectorField from './inspector/InspectorField.vue';
import SelectField from './inspector/SelectField.vue';

const props = defineProps({
  workflowId: { type: [Number, String], default: null },
});

const emit = defineEmits(['started']);

const SEARCH_DELAY = 300;
const MAX_DEALS = 20;
const KINDS = ['deal', 'contact', 'conversation'];

const { t } = useI18n();

const dialogRef = ref(null);
const kind = ref('deal');
const entityId = ref('');
const dealOptions = ref([]);
const isSearching = ref(false);
const isRunning = ref(false);

const kindOptions = computed(() =>
  KINDS.map(item => ({
    value: item,
    label: t(`AUTOMATION.WORKFLOWS.TEST.KINDS.${item.toUpperCase()}`),
  }))
);

const searchDeals = useDebounceFn(async query => {
  isSearching.value = true;
  try {
    const { data } = await dealsAPI.get({ params: { q: query } });
    dealOptions.value = (Array.isArray(data) ? data : [])
      .slice(0, MAX_DEALS)
      .map(deal => ({
        value: deal.id,
        label: deal.contact?.name
          ? `${deal.name} · ${deal.contact.name}`
          : deal.name,
      }));
  } catch {
    dealOptions.value = [];
  } finally {
    isSearching.value = false;
  }
}, SEARCH_DELAY);

const open = () => {
  kind.value = 'deal';
  entityId.value = '';
  dealOptions.value = [];
  dialogRef.value?.open();
  searchDeals('');
};

const changeKind = value => {
  kind.value = value;
  entityId.value = '';
};

const run = async () => {
  if (!entityId.value) return;
  isRunning.value = true;
  try {
    await automationWorkflowsAPI.run(props.workflowId, {
      [`${kind.value}_id`]: Number(entityId.value),
    });
    useAlert(t('AUTOMATION.WORKFLOWS.TEST.STARTED'));
    dialogRef.value?.close();
    emit('started');
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        error?.response?.data?.error ||
        t('AUTOMATION.WORKFLOWS.TEST.ERROR')
    );
  } finally {
    isRunning.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('AUTOMATION.WORKFLOWS.TEST.TITLE')"
    :description="t('AUTOMATION.WORKFLOWS.TEST.DESCRIPTION')"
    :confirm-button-label="t('AUTOMATION.WORKFLOWS.TEST.RUN')"
    :disable-confirm-button="!entityId"
    :is-loading="isRunning"
    @confirm="run"
  >
    <div class="flex flex-col gap-4">
      <InspectorField :label="t('AUTOMATION.WORKFLOWS.TEST.KIND')">
        <SelectField
          :model-value="kind"
          :options="kindOptions"
          @update:model-value="changeKind"
        />
      </InspectorField>
      <InspectorField :label="t('AUTOMATION.WORKFLOWS.TEST.TARGET')">
        <ComboBox
          v-if="kind === 'deal'"
          v-model="entityId"
          use-api-results
          :options="dealOptions"
          :loading="isSearching"
          :placeholder="t('AUTOMATION.WORKFLOWS.TEST.DEAL_PLACEHOLDER')"
          :search-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SEARCH')"
          @search="searchDeals"
        />
        <Input
          v-else
          v-model="entityId"
          type="number"
          size="sm"
          :placeholder="t('AUTOMATION.WORKFLOWS.TEST.ID_PLACEHOLDER')"
        />
      </InspectorField>
    </div>
  </Dialog>
</template>
