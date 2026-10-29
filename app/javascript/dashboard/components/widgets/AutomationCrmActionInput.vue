<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import { pipelinesAPI, customFieldsAPI, segmentsAPI } from 'dashboard/api/crm';
import AgentsAPI from 'dashboard/api/agents';

const props = defineProps({
  modelValue: { type: [Object, Array], default: () => ({}) },
  actionName: { type: String, required: true },
});

const emit = defineEmits(['update:modelValue']);
const pipelines = ref([]);
const agents = ref([]);
const segments = ref([]);
const customFields = ref([]);

const config = computed(() => {
  const value = Array.isArray(props.modelValue) ? props.modelValue[0] : props.modelValue;
  return value || {};
});

const stages = computed(() => {
  const pipeline = pipelines.value.find(item => String(item.id) === String(config.value.pipeline_id));
  return pipeline?.stages || [];
});

const pipelineOptions = computed(() => pipelines.value.map(item => ({ id: item.id, name: item.name })));
const stageOptions = computed(() => stages.value.map(item => ({ id: item.id, name: item.name })));
const agentOptions = computed(() => agents.value.map(item => ({ id: item.id, name: item.name })));
const segmentOptions = computed(() => segments.value.map(item => ({ id: item.id, name: item.name })));
const dealAction = computed(() => ['update_deal', 'upsert_deal'].includes(props.actionName));

const update = (key, value) => {
  emit('update:modelValue', { ...config.value, [key]: value || undefined });
};

const updatePipeline = event => {
  const pipelineId = event.target.value;
  const pipeline = pipelines.value.find(item => String(item.id) === String(pipelineId));
  const stageStillValid = pipeline?.stages?.some(stage => String(stage.id) === String(config.value.pipeline_stage_id));
  emit('update:modelValue', {
    ...config.value,
    pipeline_id: pipelineId || undefined,
    pipeline_stage_id: stageStillValid ? config.value.pipeline_stage_id : undefined,
  });
};

const parseJson = (value, fallback) => {
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
};

const customFieldsText = computed({
  get: () => JSON.stringify(config.value.custom_fields || {}, null, 2),
  set: value => update('custom_fields', parseJson(value, config.value.custom_fields || {})),
});

const contactFieldsText = computed({
  get: () => JSON.stringify(config.value.contact_custom_fields || {}, null, 2),
  set: value => update('contact_custom_fields', parseJson(value, config.value.contact_custom_fields || {})),
});

onMounted(async () => {
  const results = await Promise.allSettled([
    pipelinesAPI.get(),
    AgentsAPI.get(),
    segmentsAPI.get(),
    customFieldsAPI.get(),
  ]);
  pipelines.value = results[0].status === 'fulfilled' ? results[0].value.data : [];
  agents.value = results[1].status === 'fulfilled' ? results[1].value.data : [];
  segments.value = results[2].status === 'fulfilled' ? results[2].value.data : [];
  customFields.value = results[3].status === 'fulfilled' ? results[3].value.data : [];
});

watch(
  () => config.value.pipeline_id,
  pipelineId => {
    if (!pipelineId || !stages.value.length) return;
    if (!stages.value.some(stage => String(stage.id) === String(config.value.pipeline_stage_id))) {
      update('pipeline_stage_id', undefined);
    }
  }
);
</script>

<template>
  <div class="grid grid-cols-1 gap-2 p-3 rounded-lg bg-n-alpha-1 md:grid-cols-2">
    <NextInput
      v-if="['create_deal', 'update_deal', 'upsert_deal'].includes(actionName)"
      :model-value="config.name || ''"
      size="sm"
      :label="$t('AUTOMATION.CRM_ACTION.NAME')"
      :placeholder="$t('AUTOMATION.CRM_ACTION.NAME_PLACEHOLDER')"
      @update:model-value="update('name', $event)"
    />
    <label class="flex flex-col gap-1 text-sm text-n-slate-11">
      {{ $t('AUTOMATION.CRM_ACTION.PIPELINE') }}
      <select
        :value="config.pipeline_id || ''"
        class="h-9 px-2 rounded-md bg-n-alpha-2 outline outline-1 outline-n-weak"
        @change="updatePipeline"
      >
        <option value="">{{ $t('AUTOMATION.CRM_ACTION.SELECT_PIPELINE') }}</option>
        <option v-for="option in pipelineOptions" :key="option.id" :value="option.id">{{ option.name }}</option>
      </select>
    </label>
    <label class="flex flex-col gap-1 text-sm text-n-slate-11">
      {{ $t('AUTOMATION.CRM_ACTION.STAGE') }}
      <select
        :value="config.pipeline_stage_id || ''"
        class="h-9 px-2 rounded-md bg-n-alpha-2 outline outline-1 outline-n-weak"
        :disabled="!config.pipeline_id"
        @change="update('pipeline_stage_id', $event.target.value)"
      >
        <option value="">{{ $t('AUTOMATION.CRM_ACTION.SELECT_STAGE') }}</option>
        <option v-for="option in stageOptions" :key="option.id" :value="option.id">{{ option.name }}</option>
      </select>
    </label>
    <NextInput
      v-if="['create_deal', 'update_deal', 'upsert_deal'].includes(actionName)"
      :model-value="config.status || 'open'"
      size="sm"
      :label="$t('AUTOMATION.CRM_ACTION.STATUS')"
      @update:model-value="update('status', $event)"
    />
    <NextInput
      v-if="['create_deal', 'update_deal', 'upsert_deal'].includes(actionName)"
      :model-value="config.value ?? ''"
      size="sm"
      type="number"
      :label="$t('AUTOMATION.CRM_ACTION.VALUE')"
      @update:model-value="update('value', $event)"
    />
    <label class="flex flex-col gap-1 text-sm text-n-slate-11">
      {{ $t('AUTOMATION.CRM_ACTION.OWNER') }}
      <select
        :value="config.owner_id || ''"
        class="h-9 px-2 rounded-md bg-n-alpha-2 outline outline-1 outline-n-weak"
        @change="update('owner_id', $event.target.value)"
      >
        <option value="">{{ $t('AUTOMATION.CRM_ACTION.SELECT_OWNER') }}</option>
        <option v-for="option in agentOptions" :key="option.id" :value="option.id">{{ option.name }}</option>
      </select>
    </label>
    <label class="flex flex-col gap-1 text-sm text-n-slate-11">
      {{ $t('AUTOMATION.CRM_ACTION.SEGMENT') }}
      <select
        :value="config.segment_id || ''"
        class="h-9 px-2 rounded-md bg-n-alpha-2 outline outline-1 outline-n-weak"
        @change="update('segment_id', $event.target.value)"
      >
        <option value="">{{ $t('AUTOMATION.CRM_ACTION.SELECT_SEGMENT') }}</option>
        <option v-for="option in segmentOptions" :key="option.id" :value="option.id">{{ option.name }}</option>
      </select>
    </label>
    <NextInput
      v-if="['create_deal', 'update_deal', 'upsert_deal'].includes(actionName)"
      :model-value="config.description || ''"
      size="sm"
      :label="$t('AUTOMATION.CRM_ACTION.DESCRIPTION')"
      @update:model-value="update('description', $event)"
    />
    <label v-if="dealAction" class="flex flex-col gap-1 text-sm text-n-slate-11">
      {{ $t('AUTOMATION.CRM_ACTION.SELECTION') }}
      <select
        :value="config.selection || 'first_open'"
        class="h-9 px-2 rounded-md bg-n-alpha-2 outline outline-1 outline-n-weak"
        @change="update('selection', $event.target.value)"
      >
        <option value="current_deal">{{ $t('AUTOMATION.CRM_ACTION.CURRENT_DEAL') }}</option>
        <option value="first_open">{{ $t('AUTOMATION.CRM_ACTION.FIRST_OPEN') }}</option>
        <option value="recent">{{ $t('AUTOMATION.CRM_ACTION.RECENT') }}</option>
      </select>
    </label>
    <NextInput
      v-if="dealAction"
      :model-value="config.deal_id || ''"
      size="sm"
      :label="$t('AUTOMATION.CRM_ACTION.DEAL_ID')"
      :placeholder="$t('AUTOMATION.CRM_ACTION.DEAL_ID_PLACEHOLDER')"
      @update:model-value="update('deal_id', $event)"
    />
    <label class="flex flex-col gap-1 text-sm text-n-slate-11 md:col-span-2">
      {{ $t('AUTOMATION.CRM_ACTION.DEAL_FIELDS') }}
      <textarea v-model="customFieldsText" rows="2" class="p-2 rounded-md bg-n-alpha-2 outline outline-1 outline-n-weak" />
      <span class="text-xs text-n-slate-10">{{ customFields.map(field => field.key).join(', ') }}</span>
    </label>
    <label v-if="['create_deal', 'update_deal', 'upsert_deal', 'set_contact_fields'].includes(actionName)" class="flex flex-col gap-1 text-sm text-n-slate-11 md:col-span-2">
      {{ $t('AUTOMATION.CRM_ACTION.CONTACT_FIELDS') }}
      <textarea v-model="contactFieldsText" rows="2" class="p-2 rounded-md bg-n-alpha-2 outline outline-1 outline-n-weak" />
    </label>
  </div>
</template>
