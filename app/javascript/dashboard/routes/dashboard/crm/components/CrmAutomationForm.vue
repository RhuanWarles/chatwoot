<script setup>
import { computed, inject, nextTick, ref, useId } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import CrmAutomationField from './CrmAutomationField.vue';
import {
  ACTIVITY_LABEL_KEYS,
  AI_STATES,
  AI_STATE_DESCRIPTION_KEYS,
  AI_STATE_LABEL_KEYS,
  DESTINATIONS_KEY,
  MAX_DUE_IN_HOURS,
  MAX_MESSAGE_LENGTH,
  STATUSES,
  STATUS_LABEL_KEYS,
  TEMPLATE_VARIABLES,
  getActionErrors,
  getWebhookSample,
} from './automationHelpers';

const props = defineProps({
  kind: { type: String, required: true },
  autofocus: { type: Boolean, default: false },
  showErrors: { type: Boolean, default: false },
});
const action = defineModel('action', { type: Object, required: true });

const { t } = useI18n();
const uid = useId();
const agents = useMapGetter('agents/getAgents');
const labels = useMapGetter('labels/getLabels');
const destinations = inject(DESTINATIONS_KEY, ref(null));
const messageField = ref(null);
const caret = ref(null);

const errors = computed(() =>
  getActionErrors(action.value, { destinations: destinations.value })
);
const errorText = field =>
  props.showErrors && errors.value[field] ? t(errors.value[field]) : '';
const messageType = field => (errorText(field) ? 'error' : 'info');

const statusOptions = computed(() =>
  (props.kind === 'stage' ? STATUSES : ['open']).map(status => ({
    value: status,
    label: t(STATUS_LABEL_KEYS[status]),
  }))
);
const activityOptions = computed(() =>
  Object.entries(ACTIVITY_LABEL_KEYS).map(([value, labelKey]) => ({
    value,
    label: t(labelKey),
  }))
);
const agentOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);
const labelOptions = computed(() =>
  labels.value.map(label => ({ value: label.title, label: label.title }))
);
const pipelineOptions = computed(() =>
  (destinations.value ?? []).map(pipeline => ({
    value: pipeline.id,
    label:
      pipeline.active === false
        ? `${pipeline.name} (${t('CRM.INACTIVE')})`
        : pipeline.name,
  }))
);
const stageOptions = computed(() =>
  (
    (destinations.value ?? []).find(
      pipeline => pipeline.id === action.value.pipeline_id
    )?.stages ?? []
  ).map(stage => ({ value: stage.id, label: stage.name }))
);
const variables = TEMPLATE_VARIABLES.map(({ key, helpKey }) => ({
  key,
  helpKey,
  token: `{{${key}}}`,
}));
const webhookSample = computed(() =>
  JSON.stringify(getWebhookSample(props.kind), null, 2)
);

const rememberCaret = event => {
  caret.value = {
    start: event.target.selectionStart,
    end: event.target.selectionEnd,
  };
};
const insertVariable = token => {
  const element = messageField.value?.querySelector('textarea');
  const current = action.value.content || '';
  const { start, end } = caret.value ?? {
    start: current.length,
    end: current.length,
  };
  action.value.content = `${current.slice(0, start)}${token}${current.slice(end)}`;
  caret.value = null;
  nextTick(() => {
    element?.focus();
    element?.setSelectionRange(start + token.length, start + token.length);
  });
};
</script>

<template>
  <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
    <template v-if="action.type === 'set_status'">
      <CrmAutomationField
        group
        :label="t('CRM.AUTOMATION_FIELD_STATUS')"
        :error="errorText('status')"
      >
        <ComboBox
          :model-value="action.status"
          :options="statusOptions"
          :has-error="Boolean(errorText('status'))"
          @update:model-value="
            value => {
              // Re-clicking the selected option clears it; a status is always required.
              if (value) action.status = value;
            }
          "
        />
      </CrmAutomationField>
      <p
        v-if="kind !== 'stage'"
        class="m-0 text-label-small text-n-slate-11 md:col-span-2"
      >
        {{ t('CRM.AUTOMATION_OUTCOME_REOPEN_HINT') }}
      </p>
    </template>

    <CrmAutomationField
      v-else-if="action.type === 'assign_owner'"
      group
      :label="t('CRM.OWNER')"
      :error="errorText('user_id')"
    >
      <ComboBox
        v-model="action.user_id"
        :options="agentOptions"
        :placeholder="t('CRM.AUTOMATION_SELECT_OWNER')"
        :has-error="Boolean(errorText('user_id'))"
      />
    </CrmAutomationField>

    <template v-else-if="action.type === 'create_activity'">
      <CrmAutomationField
        group
        :label="t('CRM.AUTOMATION_FIELD_ACTIVITY_TYPE')"
        :error="errorText('activity_type')"
      >
        <ComboBox
          v-model="action.activity_type"
          :options="activityOptions"
          :has-error="Boolean(errorText('activity_type'))"
        />
      </CrmAutomationField>
      <CrmAutomationField
        v-slot="{ id }"
        class="md:col-span-2"
        :label="t('CRM.AUTOMATION_ACTIVITY_TITLE')"
        :error="errorText('title')"
      >
        <Input
          :id="id"
          v-model="action.title"
          :placeholder="t('CRM.AUTOMATION_ACTIVITY_TITLE_PLACEHOLDER')"
          :message-type="messageType('title')"
          :autofocus="autofocus"
        />
      </CrmAutomationField>
      <CrmAutomationField
        v-slot="{ id }"
        :label="t('CRM.AUTOMATION_DUE_IN_HOURS')"
        :hint="t('CRM.AUTOMATION_DUE_HINT')"
        :error="errorText('due_in_hours')"
      >
        <Input
          :id="id"
          v-model="action.due_in_hours"
          type="number"
          min="1"
          :max="String(MAX_DUE_IN_HOURS)"
          :message-type="messageType('due_in_hours')"
        />
      </CrmAutomationField>
    </template>

    <template v-else-if="action.type === 'add_label'">
      <CrmAutomationField
        group
        :label="t('CRM.AUTOMATION_LABEL')"
        :error="errorText('label')"
      >
        <ComboBox
          v-model="action.label"
          :options="labelOptions"
          :placeholder="t('CRM.AUTOMATION_SELECT_LABEL')"
          :empty-state="t('CRM.AUTOMATION_NO_LABELS')"
          :has-error="Boolean(errorText('label'))"
        />
      </CrmAutomationField>
      <p class="m-0 text-label-small text-n-slate-11 md:col-span-2">
        {{ t('CRM.AUTOMATION_NO_CONVERSATION_NOTE') }}
      </p>
    </template>

    <template v-else-if="action.type === 'set_ai_state'">
      <CrmAutomationField
        group
        class="md:col-span-2"
        :label="t('CRM.AUTOMATION_FIELD_AI_STATE')"
        :error="errorText('state')"
      >
        <div class="grid gap-2 sm:grid-cols-2">
          <RadioCard
            v-for="state in AI_STATES"
            :id="`${uid}-${state}`"
            :key="state"
            :name="`${uid}-ai-state`"
            :label="t(AI_STATE_LABEL_KEYS[state])"
            :description="t(AI_STATE_DESCRIPTION_KEYS[state])"
            :is-active="action.state === state"
            @select="action.state = state"
          />
        </div>
      </CrmAutomationField>
      <p class="m-0 text-label-small text-n-slate-11 md:col-span-2">
        {{ t('CRM.AUTOMATION_NO_CONVERSATION_NOTE') }}
      </p>
    </template>

    <template v-else-if="action.type === 'send_message'">
      <CrmAutomationField
        v-slot="{ id }"
        class="md:col-span-2"
        :label="t('CRM.AUTOMATION_FIELD_MESSAGE')"
        :error="errorText('content')"
      >
        <div ref="messageField">
          <TextArea
            :id="id"
            v-model="action.content"
            :placeholder="t('CRM.AUTOMATION_MESSAGE_PLACEHOLDER')"
            :max-length="MAX_MESSAGE_LENGTH"
            :message-type="messageType('content')"
            :autofocus="autofocus"
            show-character-count
            auto-height
            min-height="6rem"
            max-height="16rem"
            @blur="rememberCaret"
          />
        </div>
      </CrmAutomationField>
      <div class="flex flex-col gap-2 md:col-span-2">
        <div class="flex flex-col gap-0.5">
          <p class="m-0 text-heading-3 text-n-slate-12">
            {{ t('CRM.AUTOMATION_VARIABLES') }}
          </p>
          <p class="m-0 text-label-small text-n-slate-11">
            {{ t('CRM.AUTOMATION_VARIABLES_HINT') }}
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <Button
            v-for="variable in variables"
            :key="variable.key"
            type="button"
            variant="faded"
            color="slate"
            size="xs"
            :label="variable.token"
            :title="t(variable.helpKey)"
            :aria-label="
              t('CRM.AUTOMATION_VARIABLE_INSERT', { variable: variable.token })
            "
            @click="insertVariable(variable.token)"
          />
        </div>
      </div>
      <p class="m-0 text-label-small text-n-slate-11 md:col-span-2">
        {{ t('CRM.AUTOMATION_NO_CONVERSATION_NOTE') }}
      </p>
    </template>

    <template v-else-if="action.type === 'move_stage'">
      <CrmAutomationField
        group
        :label="t('CRM.AUTOMATION_FIELD_PIPELINE')"
        :error="errorText('pipeline_id')"
      >
        <ComboBox
          v-model="action.pipeline_id"
          :options="pipelineOptions"
          :placeholder="t('CRM.SELECT_PIPELINE')"
          :empty-state="t('CRM.AUTOMATION_NO_DESTINATIONS')"
          :has-error="Boolean(errorText('pipeline_id'))"
          @update:model-value="action.stage_id = null"
        />
      </CrmAutomationField>
      <CrmAutomationField
        group
        :label="t('CRM.AUTOMATION_FIELD_STAGE')"
        :error="errorText('stage_id')"
      >
        <ComboBox
          v-model="action.stage_id"
          :options="stageOptions"
          :placeholder="t('CRM.AUTOMATION_SELECT_STAGE')"
          :has-error="Boolean(errorText('stage_id'))"
        />
      </CrmAutomationField>
      <p class="m-0 text-label-small text-n-slate-11 md:col-span-2">
        {{ t('CRM.AUTOMATION_DESTINATION_HINT') }}
      </p>
      <p
        v-if="kind !== 'stage'"
        class="m-0 text-label-small text-n-slate-11 md:col-span-2"
      >
        {{ t('CRM.AUTOMATION_OUTCOME_MOVE_HINT') }}
      </p>
    </template>

    <template v-else-if="action.type === 'send_webhook'">
      <CrmAutomationField
        v-slot="{ id }"
        class="md:col-span-2"
        :label="t('CRM.AUTOMATION_WEBHOOK_URL')"
        :hint="t('CRM.AUTOMATION_WEBHOOK_HELP')"
        :error="errorText('url')"
      >
        <Input
          :id="id"
          v-model="action.url"
          type="text"
          inputmode="url"
          autocomplete="off"
          placeholder="https://"
          :message-type="messageType('url')"
          :autofocus="autofocus"
        />
      </CrmAutomationField>
      <Accordion
        class="md:col-span-2"
        :title="t('CRM.AUTOMATION_WEBHOOK_PAYLOAD')"
      >
        <p class="mt-0 mb-3 text-label-small text-n-slate-11">
          {{ t('CRM.AUTOMATION_WEBHOOK_PAYLOAD_HELP') }}
        </p>
        <div
          class="p-3 overflow-x-auto font-mono text-xs whitespace-pre rounded-lg bg-n-solid-2 text-n-slate-12"
        >
          {{ webhookSample }}
        </div>
      </Accordion>
    </template>
  </div>
</template>
