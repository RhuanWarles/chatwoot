<script setup>
import { computed, inject, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import CrmAutomationField from './CrmAutomationField.vue';
import CrmAutomationFieldValue from './CrmAutomationFieldValue.vue';
import {
  CUSTOM_FIELDS_KEY,
  createCondition,
  getConditionErrors,
  getFieldOperators,
  getOperatorLabelKey,
  isValuelessOperator,
} from './automationHelpers';

defineProps({
  showErrors: { type: Boolean, default: false },
});
// An action only runs when the custom field of the deal matches the condition.
const condition = defineModel('condition', { type: Object, default: null });

const { t } = useI18n();
const fields = inject(CUSTOM_FIELDS_KEY, ref(null));

const enabled = computed({
  get: () => Boolean(condition.value),
  set: value => {
    condition.value = value ? createCondition() : null;
  },
});
const field = computed(() =>
  (fields.value ?? []).find(({ id }) => id === condition.value?.custom_field_id)
);
const errors = computed(() =>
  condition.value
    ? getConditionErrors(condition.value, { fields: fields.value })
    : {}
);
const errorText = key => (errors.value[key] ? t(errors.value[key]) : '');
const fieldOptions = computed(() =>
  (fields.value ?? []).map(({ id, name }) => ({ value: id, label: name }))
);
const operatorOptions = computed(() =>
  getFieldOperators(field.value).map(operator => ({
    value: operator,
    label: t(getOperatorLabelKey(operator, field.value)),
  }))
);

// A new field can have other operators and other kinds of values.
const changeField = id => {
  condition.value = { ...createCondition(), custom_field_id: id };
};
const changeOperator = operator => {
  condition.value = {
    ...condition.value,
    operator,
    value: isValuelessOperator(operator) ? '' : condition.value.value,
  };
};
</script>

<template>
  <div class="flex flex-col gap-3 pt-4 mt-4 border-t border-n-weak">
    <label class="flex items-start gap-3 cursor-pointer">
      <Switch v-model="enabled" class="mt-0.5" />
      <span class="flex flex-col gap-0.5">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('CRM.AUTOMATION_CONDITION_TITLE') }}
        </span>
        <span class="text-label-small text-n-slate-11">
          {{ t('CRM.AUTOMATION_CONDITION_HINT') }}
        </span>
      </span>
    </label>
    <div
      v-if="condition"
      class="grid grid-cols-1 gap-4 md:grid-cols-3"
      data-test="condition-editor"
    >
      <CrmAutomationField
        group
        :label="t('CRM.AUTOMATION_CONDITION_FIELD')"
        :error="showErrors ? errorText('custom_field_id') : ''"
      >
        <ComboBox
          :model-value="condition.custom_field_id"
          :options="fieldOptions"
          :placeholder="t('CRM.AUTOMATION_SELECT_FIELD')"
          :empty-state="t('CRM.AUTOMATION_NO_FIELDS')"
          :has-error="showErrors && Boolean(errorText('custom_field_id'))"
          @update:model-value="changeField"
        />
      </CrmAutomationField>
      <CrmAutomationField
        group
        :label="t('CRM.AUTOMATION_CONDITION_OPERATOR')"
        :error="showErrors ? errorText('operator') : ''"
      >
        <ComboBox
          :model-value="condition.operator"
          :options="operatorOptions"
          :has-error="showErrors && Boolean(errorText('operator'))"
          @update:model-value="changeOperator"
        />
      </CrmAutomationField>
      <CrmAutomationField
        v-if="!isValuelessOperator(condition.operator)"
        group
        :label="t('CRM.AUTOMATION_CONDITION_VALUE')"
        :error="showErrors ? errorText('value') : ''"
      >
        <CrmAutomationFieldValue
          v-model="condition.value"
          :field="field"
          :has-error="showErrors && Boolean(errorText('value'))"
        />
      </CrmAutomationField>
    </div>
  </div>
</template>
