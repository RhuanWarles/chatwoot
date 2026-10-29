<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import InspectorField from './InspectorField.vue';
import KeyValueListEditor from './KeyValueListEditor.vue';
import SelectField from './SelectField.vue';
import TemplateTextField from './TemplateTextField.vue';
import { useWorkflowLookups } from '../../useWorkflowLookups';
import { PARAM_TYPES } from '../../actions';
import { STATIC_OPTIONS, optionLabelKey } from '../../constants';

const props = defineProps({
  action: { type: String, required: true },
  definition: { type: Object, required: true },
  params: { type: Object, required: true },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['update']);

const { t, te } = useI18n();
const { lookups } = useWorkflowLookups();

const type = computed(() => props.definition.type);
const value = computed(() => props.params[props.definition.key]);

const label = computed(() => {
  const specific = `AUTOMATION.WORKFLOWS.PARAMS.${props.action.toUpperCase()}_${props.definition.key.toUpperCase()}`;
  return t(
    te(specific)
      ? specific
      : `AUTOMATION.WORKFLOWS.PARAMS.${props.definition.key.toUpperCase()}`
  );
});

const set = next => emit('update', props.definition.key, next);

const withSpecials = options => [
  ...(props.definition.specials || []).map(special => ({
    value: special,
    label: t(`AUTOMATION.WORKFLOWS.SPECIAL.${special.toUpperCase()}`),
  })),
  ...options,
];

const staticOptions = computed(() =>
  (STATIC_OPTIONS[props.definition.options] || []).map(item => ({
    value: item,
    label: t(optionLabelKey(props.definition.options, item)),
  }))
);

const comboOptions = computed(() => {
  switch (type.value) {
    case PARAM_TYPES.AGENT:
      return withSpecials(lookups.value.options('agent'));
    case PARAM_TYPES.TEAM:
      return withSpecials(lookups.value.options('team'));
    case PARAM_TYPES.PIPELINE:
      return lookups.value.options('pipeline');
    case PARAM_TYPES.STAGE:
      return lookups.value.stagesOf(props.params.pipeline_id);
    case PARAM_TYPES.SEGMENT:
      return lookups.value.options('segment');
    case PARAM_TYPES.LOST_REASON:
      return lookups.value.options('lost_reason');
    default:
      return [];
  }
});

const COMBO_TYPES = [
  PARAM_TYPES.AGENT,
  PARAM_TYPES.TEAM,
  PARAM_TYPES.PIPELINE,
  PARAM_TYPES.STAGE,
  PARAM_TYPES.SEGMENT,
  PARAM_TYPES.LOST_REASON,
];
const TEXT_TYPES = [PARAM_TYPES.TEMPLATE_TEXT, PARAM_TYPES.TEMPLATE_LINE];

const isCombo = computed(() => COMBO_TYPES.includes(type.value));
const isText = computed(() => TEXT_TYPES.includes(type.value));
const isDisabled = computed(
  () => type.value === PARAM_TYPES.STAGE && !props.params.pipeline_id
);
const error = computed(() =>
  props.hasError ? t('AUTOMATION.WORKFLOWS.VALIDATION.PARAM_REQUIRED') : ''
);
const fieldKeyOptions = computed(() =>
  type.value === PARAM_TYPES.DEAL_FIELDS
    ? lookups.value.dealFields
    : lookups.value.contactFields
);
const comboValue = computed(() => value.value ?? '');

const setNumber = raw => set(raw === '' ? '' : Number(raw));
const setTags = tags => set([...tags]);
</script>

<template>
  <InspectorField :label="label" :error="error">
    <TemplateTextField
      v-if="isText"
      :model-value="String(value ?? '')"
      :multiline="type === PARAM_TYPES.TEMPLATE_TEXT"
      :plain="Boolean(definition.plain)"
      @update:model-value="set"
    />
    <Input
      v-else-if="type === PARAM_TYPES.NUMBER"
      :model-value="comboValue"
      type="number"
      min="0"
      size="sm"
      @update:model-value="setNumber"
    />
    <div
      v-else-if="type === PARAM_TYPES.CHECKBOX"
      class="flex items-center gap-2"
    >
      <Switch :model-value="Boolean(value)" @update:model-value="set" />
      <span class="text-sm text-n-slate-11">
        {{
          t(`AUTOMATION.WORKFLOWS.PARAM_HINTS.${definition.key.toUpperCase()}`)
        }}
      </span>
    </div>
    <SelectField
      v-else-if="type === PARAM_TYPES.STATIC"
      :model-value="comboValue"
      :options="staticOptions"
      :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SELECT')"
      :error="error"
      @update:model-value="set"
    />
    <ComboBox
      v-else-if="isCombo"
      :model-value="comboValue"
      :options="comboOptions"
      :display-label="String(comboValue)"
      :disabled="isDisabled"
      :has-error="hasError"
      :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SELECT')"
      :search-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SEARCH')"
      @update:model-value="set"
    />
    <TagMultiSelectComboBox
      v-else-if="type === PARAM_TYPES.AGENTS_MULTI"
      :model-value="[...(value || [])]"
      :options="lookups.options('agent')"
      :has-error="hasError"
      :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SELECT')"
      :search-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SEARCH')"
      @update:model-value="setTags"
    />
    <TagMultiSelectComboBox
      v-else-if="type === PARAM_TYPES.LABELS"
      :model-value="[...(value || [])]"
      :options="lookups.labelOptions"
      :has-error="hasError"
      :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SELECT')"
      :search-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SEARCH')"
      @update:model-value="setTags"
    />
    <KeyValueListEditor
      v-else-if="type === PARAM_TYPES.HEADERS"
      :model-value="value || []"
      :key-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.HEADER_NAME')"
      :value-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.HEADER_VALUE')"
      :add-label="t('AUTOMATION.WORKFLOWS.INSPECTOR.ADD_HEADER')"
      @update:model-value="set"
    />
    <KeyValueListEditor
      v-else
      :model-value="value || []"
      :key-options="fieldKeyOptions"
      :key-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.FIELD_PLACEHOLDER')"
      :value-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.VALUE_PLACEHOLDER')"
      :add-label="t('AUTOMATION.WORKFLOWS.INSPECTOR.ADD_FIELD')"
      @update:model-value="set"
    />
  </InspectorField>
</template>
