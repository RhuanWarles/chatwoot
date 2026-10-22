<script>
export const isAutomationValid = action => {
  switch (action.type) {
    case 'set_status':
      return ['open', 'won', 'lost'].includes(action.status);
    case 'assign_owner':
      return Number.isInteger(action.user_id);
    case 'create_activity':
      return Boolean(
        action.activity_type &&
          action.title?.trim() &&
          Number.isInteger(action.due_in_hours) &&
          action.due_in_hours >= 1
      );
    case 'add_label':
      return Boolean(action.label);
    case 'set_ai_state':
      return ['ai', 'human'].includes(action.state);
    case 'send_message':
      return Boolean(action.content?.trim());
    case 'move_stage':
      return (
        Number.isInteger(action.pipeline_id) &&
        Number.isInteger(action.stage_id)
      );
    case 'send_webhook':
      return /^https?:\/\/\S+$/.test(action.url || '');
    default:
      return false;
  }
};

const DEFAULTS = {
  set_status: { status: 'won' },
  assign_owner: { user_id: null },
  create_activity: { activity_type: 'follow_up', title: '', due_in_hours: 24 },
  add_label: { label: '' },
  set_ai_state: { state: 'human' },
  send_message: { content: '' },
  move_stage: { pipeline_id: null, stage_id: null },
  send_webhook: { url: '' },
};
</script>

<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { pipelinesAPI } from 'dashboard/api/crm';

const automations = defineModel('automations', {
  type: Array,
  default: () => [],
});
const aiInstructions = defineModel('aiInstructions', { type: String });

const { t } = useI18n();
const agents = useMapGetter('agents/getAgents');
const labels = useMapGetter('labels/getLabels');
const open = ref(false);

const typeOptions = computed(() =>
  Object.keys(DEFAULTS).map(type => ({
    value: type,
    label: t(`CRM.AUTOMATION_TYPE_${type.toUpperCase()}`),
  }))
);
const statusOptions = computed(() =>
  ['open', 'won', 'lost'].map(status => ({
    value: status,
    label: t(`CRM.STATUS_${status.toUpperCase()}`),
  }))
);
const activityOptions = computed(() =>
  ['task', 'call', 'meeting', 'follow_up'].map(type => ({
    value: type,
    label: t(`CRM.AUTOMATION_ACTIVITY_TYPE_${type.toUpperCase()}`),
  }))
);
const aiStateOptions = computed(() =>
  ['ai', 'human'].map(state => ({
    value: state,
    label: t(`CRM.AUTOMATION_AI_STATE_${state.toUpperCase()}`),
  }))
);
const agentOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);
const labelOptions = computed(() =>
  labels.value.map(label => ({ value: label.title, label: label.title }))
);

const pipelines = ref([]);
const pipelineOptions = computed(() =>
  pipelines.value.map(pipeline => ({
    value: pipeline.id,
    label: pipeline.name,
  }))
);
const stageOptions = action =>
  (
    pipelines.value.find(pipeline => pipeline.id === action.pipeline_id)
      ?.stages || []
  ).map(stage => ({ value: stage.id, label: stage.name }));
watch(
  () => automations.value.some(action => action.type === 'move_stage'),
  async needsPipelines => {
    if (needsPipelines && !pipelines.value.length) {
      pipelines.value = (await pipelinesAPI.get()).data;
    }
  },
  { immediate: true }
);

const add = () => {
  automations.value = [
    ...automations.value,
    { type: 'set_status', ...DEFAULTS.set_status },
  ];
};
const changeType = (index, type) => {
  automations.value = automations.value.map((action, position) =>
    position === index ? { type, ...DEFAULTS[type] } : action
  );
};
const remove = index => {
  automations.value = automations.value.filter(
    (_, position) => position !== index
  );
};
</script>

<template>
  <div class="flex flex-col gap-3 pt-3 border-t border-n-weak">
    <Button
      type="button"
      variant="ghost"
      color="slate"
      size="sm"
      class="justify-start"
      :icon="open ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
      :label="t('CRM.AUTOMATIONS_TITLE', { count: automations.length })"
      :aria-expanded="open"
      @click="open = !open"
    />
    <div v-if="open" class="flex flex-col gap-3">
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('CRM.AI_INSTRUCTIONS') }}
        <textarea
          v-model="aiInstructions"
          rows="3"
          class="w-full p-2 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12"
          :placeholder="t('CRM.AI_INSTRUCTIONS_PLACEHOLDER')"
        />
      </label>
      <p class="mb-0 text-xs text-n-slate-11">
        {{ t('CRM.AUTOMATIONS_HELP') }}
      </p>
      <div
        v-for="(action, index) in automations"
        :key="index"
        class="flex flex-col gap-2 p-2 rounded-lg bg-n-alpha-2"
      >
        <div class="flex items-center gap-1">
          <ComboBox
            class="flex-1 min-w-0"
            :model-value="action.type"
            :options="typeOptions"
            @update:model-value="changeType(index, $event)"
          />
          <Button
            type="button"
            variant="ghost"
            color="ruby"
            size="sm"
            icon="i-lucide-trash-2"
            :aria-label="t('CRM.AUTOMATION_REMOVE')"
            @click="remove(index)"
          />
        </div>
        <ComboBox
          v-if="action.type === 'set_status'"
          v-model="action.status"
          :options="statusOptions"
        />
        <ComboBox
          v-else-if="action.type === 'assign_owner'"
          v-model="action.user_id"
          :options="agentOptions"
          :placeholder="t('CRM.OWNER')"
        />
        <template v-else-if="action.type === 'create_activity'">
          <ComboBox v-model="action.activity_type" :options="activityOptions" />
          <Input
            v-model="action.title"
            :placeholder="t('CRM.AUTOMATION_ACTIVITY_TITLE')"
          />
          <Input
            v-model.number="action.due_in_hours"
            type="number"
            min="1"
            :label="t('CRM.AUTOMATION_DUE_IN_HOURS')"
          />
        </template>
        <ComboBox
          v-else-if="action.type === 'add_label'"
          v-model="action.label"
          :options="labelOptions"
          :placeholder="t('CRM.AUTOMATION_LABEL')"
        />
        <ComboBox
          v-else-if="action.type === 'set_ai_state'"
          v-model="action.state"
          :options="aiStateOptions"
        />
        <template v-else-if="action.type === 'send_message'">
          <textarea
            v-model="action.content"
            rows="3"
            class="w-full p-2 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12"
            :placeholder="t('CRM.AUTOMATION_MESSAGE_PLACEHOLDER')"
          />
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('CRM.AUTOMATION_MESSAGE_VARIABLES') }}
          </p>
        </template>
        <template v-else-if="action.type === 'move_stage'">
          <ComboBox
            v-model="action.pipeline_id"
            :options="pipelineOptions"
            :placeholder="t('CRM.SELECT_PIPELINE')"
            @update:model-value="action.stage_id = null"
          />
          <ComboBox
            v-model="action.stage_id"
            :options="stageOptions(action)"
            :placeholder="t('CRM.STAGE')"
          />
        </template>
        <template v-else-if="action.type === 'send_webhook'">
          <Input
            v-model="action.url"
            type="url"
            placeholder="https://"
            :label="t('CRM.AUTOMATION_WEBHOOK_URL')"
          />
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('CRM.AUTOMATION_WEBHOOK_HELP') }}
          </p>
        </template>
      </div>
      <Button
        type="button"
        variant="faded"
        color="slate"
        size="sm"
        icon="i-lucide-plus"
        :label="t('CRM.AUTOMATION_ADD')"
        @click="add"
      />
    </div>
  </div>
</template>
