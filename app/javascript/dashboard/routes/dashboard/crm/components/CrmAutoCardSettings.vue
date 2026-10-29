<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import { autoCardSettingsAPI } from 'dashboard/api/crm';

const props = defineProps({
  pipelines: { type: Array, default: () => [] },
});

const { t } = useI18n();
const enabled = ref(true);
// ComboBox works with '' for "nothing chosen"; the API uses null.
const pipelineId = ref('');
const stageId = ref('');
const saving = ref(false);
const loaded = ref(false);

const pipelineOptions = computed(() => [
  { value: '', label: t('CRM.AUTO_CARD_PIPELINE_AUTO') },
  ...props.pipelines
    .filter(pipeline => pipeline.active)
    .map(pipeline => ({ value: pipeline.id, label: pipeline.name })),
]);

const stageOptions = computed(() => {
  const pipeline = props.pipelines.find(item => item.id === pipelineId.value);
  return [
    { value: '', label: t('CRM.AUTO_CARD_FIRST_STAGE') },
    ...(pipeline?.stages || []).map(stage => ({
      value: stage.id,
      label: stage.name,
    })),
  ];
});

const applySettings = settings => {
  enabled.value = settings.enabled;
  pipelineId.value = settings.pipeline_id ?? '';
  stageId.value = settings.stage_id ?? '';
};

const changePipeline = value => {
  pipelineId.value = value;
  stageId.value = '';
};

const load = async () => {
  try {
    applySettings((await autoCardSettingsAPI.getSettings()).data);
    loaded.value = true;
  } catch {
    useAlert(t('CRM.AUTO_CARD_LOAD_ERROR'));
  }
};

const save = async () => {
  saving.value = true;
  try {
    const { data } = await autoCardSettingsAPI.updateSettings({
      enabled: enabled.value,
      pipeline_id: pipelineId.value === '' ? null : pipelineId.value,
      stage_id:
        pipelineId.value === '' || stageId.value === '' ? null : stageId.value,
    });
    applySettings(data);
    useAlert(t('CRM.AUTO_CARD_SAVED'));
  } catch (error) {
    useAlert(error?.response?.data?.message || t('CRM.AUTO_CARD_SAVE_ERROR'));
  } finally {
    saving.value = false;
  }
};

onMounted(load);
</script>

<template>
  <section
    class="flex flex-col gap-3 p-4 mb-5 rounded-xl border border-n-weak bg-n-alpha-1"
    :aria-label="t('CRM.AUTO_CARD_TITLE')"
  >
    <div class="flex flex-col gap-1">
      <h2 class="m-0 text-base font-medium text-n-slate-12">
        {{ t('CRM.AUTO_CARD_TITLE') }}
      </h2>
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CRM.AUTO_CARD_DESCRIPTION') }}
      </p>
    </div>
    <label class="flex items-center gap-2 text-sm text-n-slate-12">
      <Switch v-model="enabled" :disabled="!loaded || saving" />
      <span>{{ t('CRM.AUTO_CARD_ENABLED') }}</span>
    </label>
    <div v-if="enabled" class="grid gap-3 sm:grid-cols-2">
      <div class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CRM.AUTO_CARD_PIPELINE') }}
        </span>
        <ComboBox
          :model-value="pipelineId"
          :options="pipelineOptions"
          :disabled="!loaded || saving"
          :placeholder="t('CRM.AUTO_CARD_PIPELINE_AUTO')"
          @update:model-value="changePipeline"
        />
      </div>
      <div v-if="pipelineId !== ''" class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CRM.AUTO_CARD_STAGE') }}
        </span>
        <ComboBox
          v-model="stageId"
          :options="stageOptions"
          :disabled="!loaded || saving"
          :placeholder="t('CRM.AUTO_CARD_FIRST_STAGE')"
        />
      </div>
    </div>
    <div>
      <Button
        :label="t('CRM.AUTO_CARD_SAVE')"
        size="sm"
        :is-loading="saving"
        :disabled="!loaded"
        @click="save"
      />
    </div>
  </section>
</template>
