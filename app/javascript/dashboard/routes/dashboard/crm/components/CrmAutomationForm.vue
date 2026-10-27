<script setup>
import { computed, inject, nextTick, ref, useId } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import CrmAutomationCondition from './CrmAutomationCondition.vue';
import CrmAutomationField from './CrmAutomationField.vue';
import CrmAutomationFieldValue from './CrmAutomationFieldValue.vue';
import {
  ACTIVITY_LABEL_KEYS,
  AI_STATES,
  AI_STATE_DESCRIPTION_KEYS,
  AI_STATE_LABEL_KEYS,
  CUSTOM_FIELDS_KEY,
  DESTINATIONS_KEY,
  MAX_DUE_IN_HOURS,
  MAX_MESSAGE_LENGTH,
  MAX_ROUTES,
  STATUSES,
  STATUS_LABEL_KEYS,
  TEMPLATE_VARIABLES,
  createRoute,
  getActionErrors,
  getFieldOperators,
  getOperatorLabelKey,
  getRouteErrors,
  getWebhookSample,
  isValuelessOperator,
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
const fields = inject(CUSTOM_FIELDS_KEY, ref(null));
const messageField = ref(null);
const caret = ref(null);

const errors = computed(() =>
  getActionErrors(action.value, {
    destinations: destinations.value,
    fields: fields.value,
  })
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
const customField = computed(() =>
  (fields.value ?? []).find(({ id }) => id === action.value.custom_field_id)
);
const fieldOptions = computed(() =>
  (fields.value ?? []).map(({ id, name }) => ({ value: id, label: name }))
);
const operatorOptions = computed(() =>
  getFieldOperators(customField.value).map(operator => ({
    value: operator,
    label: t(getOperatorLabelKey(operator, customField.value)),
  }))
);
const stageOptionsFor = pipelineId =>
  (
    (destinations.value ?? []).find(pipeline => pipeline.id === pipelineId)
      ?.stages ?? []
  ).map(stage => ({ value: stage.id, label: stage.name }));
const routeErrors = route =>
  props.showErrors
    ? getRouteErrors(route, {
        destinations: destinations.value,
        field: customField.value,
      })
    : {};
const routeError = (route, key) =>
  routeErrors(route)[key] ? t(routeErrors(route)[key]) : '';
// A new field has other operators and other kinds of values, so the old rules would no longer make sense.
const changeRouteField = id => {
  action.value.custom_field_id = id;
  action.value.routes = [createRoute()];
};
const changeRouteOperator = (route, operator) => {
  route.operator = operator;
  if (isValuelessOperator(operator)) route.value = '';
};
const addRoute = () => {
  action.value.routes = [...action.value.routes, createRoute()];
};
const removeRoute = index => {
  action.value.routes = action.value.routes.filter((_, i) => i !== index);
};
const toggleFallback = () => {
  action.value.fallback = action.value.fallback
    ? null
    : { pipeline_id: null, stage_id: null };
};
const fallbackErrors = computed(() =>
  props.showErrors && action.value.fallback
    ? getRouteErrors(
        { ...action.value.fallback, operator: 'filled' },
        { destinations: destinations.value }
      )
    : {}
);
const changeSetField = id => {
  action.value.custom_field_id = id;
  action.value.value = '';
};
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

    <template v-else-if="action.type === 'assign_random'">
      <CrmAutomationField
        group
        class="md:col-span-2"
        :label="t('CRM.AUTOMATION_RANDOM_OWNERS')"
        :hint="t('CRM.AUTOMATION_RANDOM_HINT')"
        :error="errorText('user_ids')"
      >
        <TagMultiSelectComboBox
          v-model="action.user_ids"
          :options="agentOptions"
          :placeholder="t('CRM.AUTOMATION_SELECT_OWNERS')"
          :has-error="Boolean(errorText('user_ids'))"
        />
      </CrmAutomationField>
    </template>

    <template v-else-if="action.type === 'set_field'">
      <CrmAutomationField
        group
        :label="t('CRM.AUTOMATION_FIELD_CUSTOM_FIELD')"
        :error="errorText('custom_field_id')"
      >
        <ComboBox
          :model-value="action.custom_field_id"
          :options="fieldOptions"
          :placeholder="t('CRM.AUTOMATION_SELECT_FIELD')"
          :empty-state="t('CRM.AUTOMATION_NO_FIELDS')"
          :has-error="Boolean(errorText('custom_field_id'))"
          @update:model-value="changeSetField"
        />
      </CrmAutomationField>
      <CrmAutomationField
        v-if="customField"
        group
        :label="t('CRM.AUTOMATION_FIELD_VALUE')"
        :error="errorText('value')"
      >
        <CrmAutomationFieldValue
          v-model="action.value"
          :field="customField"
          multiple
          :has-error="Boolean(errorText('value'))"
        />
      </CrmAutomationField>
    </template>

    <template v-else-if="action.type === 'route_by_field'">
      <CrmAutomationField
        group
        class="md:col-span-2"
        :label="t('CRM.AUTOMATION_ROUTE_FIELD')"
        :hint="t('CRM.AUTOMATION_ROUTE_HINT')"
        :error="errorText('custom_field_id')"
      >
        <ComboBox
          :model-value="action.custom_field_id"
          :options="fieldOptions"
          :placeholder="t('CRM.AUTOMATION_SELECT_FIELD')"
          :empty-state="t('CRM.AUTOMATION_NO_FIELDS')"
          :has-error="Boolean(errorText('custom_field_id'))"
          @update:model-value="changeRouteField"
        />
      </CrmAutomationField>
      <div
        v-if="customField"
        class="flex flex-col gap-3 md:col-span-2"
        data-test="routes"
      >
        <p
          v-if="errorText('routes')"
          class="m-0 text-label-small text-n-ruby-11"
        >
          {{ errorText('routes') }}
        </p>
        <div
          v-for="(route, index) in action.routes"
          :key="route.key"
          class="grid grid-cols-1 gap-3 p-3 rounded-lg md:grid-cols-[1fr_1fr_auto] bg-n-solid-2"
          data-test="route"
        >
          <div class="flex flex-col gap-3 md:col-span-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('CRM.AUTOMATION_ROUTE_WHEN', { number: index + 1 }) }}
            </span>
            <ComboBox
              :model-value="route.operator"
              :options="operatorOptions"
              :has-error="Boolean(routeError(route, 'operator'))"
              @update:model-value="changeRouteOperator(route, $event)"
            />
            <CrmAutomationFieldValue
              v-if="!isValuelessOperator(route.operator)"
              v-model="route.value"
              :field="customField"
              :has-error="Boolean(routeError(route, 'value'))"
            />
            <p
              v-if="routeError(route, 'value') || routeError(route, 'operator')"
              class="m-0 text-label-small text-n-ruby-11"
            >
              {{ routeError(route, 'value') || routeError(route, 'operator') }}
            </p>
          </div>
          <div class="flex flex-col gap-3 md:col-span-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('CRM.AUTOMATION_ROUTE_SEND_TO') }}
            </span>
            <ComboBox
              v-model="route.pipeline_id"
              :options="pipelineOptions"
              :placeholder="t('CRM.SELECT_PIPELINE')"
              :empty-state="t('CRM.AUTOMATION_NO_DESTINATIONS')"
              :has-error="Boolean(routeError(route, 'pipeline_id'))"
              @update:model-value="route.stage_id = null"
            />
            <ComboBox
              v-model="route.stage_id"
              :options="stageOptionsFor(route.pipeline_id)"
              :placeholder="t('CRM.AUTOMATION_SELECT_STAGE')"
              :has-error="Boolean(routeError(route, 'stage_id'))"
            />
            <p
              v-if="
                routeError(route, 'pipeline_id') ||
                routeError(route, 'stage_id')
              "
              class="m-0 text-label-small text-n-ruby-11"
            >
              {{
                routeError(route, 'pipeline_id') ||
                routeError(route, 'stage_id')
              }}
            </p>
          </div>
          <Button
            type="button"
            variant="ghost"
            color="ruby"
            size="xs"
            icon="i-lucide-trash-2"
            class="self-start"
            :disabled="action.routes.length === 1"
            :aria-label="t('CRM.AUTOMATION_ROUTE_REMOVE')"
            @click="removeRoute(index)"
          />
        </div>
        <Button
          type="button"
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-plus"
          class="self-start"
          :label="t('CRM.AUTOMATION_ROUTE_ADD')"
          :disabled="action.routes.length >= MAX_ROUTES"
          @click="addRoute"
        />
        <div class="flex flex-col gap-3 pt-3 border-t border-n-weak">
          <Button
            type="button"
            variant="link"
            color="blue"
            size="sm"
            class="self-start"
            :label="
              action.fallback
                ? t('CRM.AUTOMATION_FALLBACK_REMOVE')
                : t('CRM.AUTOMATION_FALLBACK_ADD')
            "
            @click="toggleFallback"
          />
          <div
            v-if="action.fallback"
            class="grid grid-cols-1 gap-3 md:grid-cols-2"
            data-test="fallback"
          >
            <ComboBox
              v-model="action.fallback.pipeline_id"
              :options="pipelineOptions"
              :placeholder="t('CRM.SELECT_PIPELINE')"
              :has-error="Boolean(fallbackErrors.pipeline_id)"
              @update:model-value="action.fallback.stage_id = null"
            />
            <ComboBox
              v-model="action.fallback.stage_id"
              :options="stageOptionsFor(action.fallback.pipeline_id)"
              :placeholder="t('CRM.AUTOMATION_SELECT_STAGE')"
              :has-error="Boolean(fallbackErrors.stage_id)"
            />
            <p class="m-0 text-label-small text-n-slate-11 md:col-span-2">
              {{ t('CRM.AUTOMATION_FALLBACK_HINT') }}
            </p>
          </div>
        </div>
      </div>
    </template>

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

    <CrmAutomationCondition
      v-model:condition="action.condition"
      class="md:col-span-2"
      :show-errors="showErrors"
    />
  </div>
</template>
