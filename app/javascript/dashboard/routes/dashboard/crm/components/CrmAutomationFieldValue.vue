<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  field: { type: Object, default: null },
  // A multiselect field holds a list when a value is written to it, and a single option when it is compared.
  multiple: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
  placeholder: { type: String, default: '' },
});
const model = defineModel({ type: [String, Number, Array], default: '' });

const { t } = useI18n();

const type = computed(() => props.field?.field_type);
const options = computed(() =>
  (props.field?.options || []).map(option => ({
    value: option,
    label: option,
  }))
);
const booleanOptions = computed(() => [
  { value: 'true', label: t('CRM.AUTOMATION_BOOLEAN_TRUE') },
  { value: 'false', label: t('CRM.AUTOMATION_BOOLEAN_FALSE') },
]);
const inputType = computed(
  () =>
    ({
      number: 'number',
      currency: 'number',
      date: 'date',
      datetime: 'datetime-local',
    })[type.value] || 'text'
);
// Values are stored as text, whatever the field type is.
const setText = value => {
  model.value = value === '' || value == null ? '' : String(value);
};
</script>

<template>
  <TagMultiSelectComboBox
    v-if="type === 'multiselect' && multiple"
    :model-value="Array.isArray(model) ? model : []"
    :options="options"
    :placeholder="placeholder"
    :has-error="hasError"
    @update:model-value="model = $event"
  />
  <ComboBox
    v-else-if="type === 'select' || type === 'multiselect'"
    v-model="model"
    :options="options"
    :placeholder="placeholder"
    :has-error="hasError"
  />
  <ComboBox
    v-else-if="type === 'boolean'"
    v-model="model"
    :options="booleanOptions"
    :placeholder="placeholder"
    :has-error="hasError"
  />
  <Input
    v-else
    :model-value="model"
    :type="inputType"
    :placeholder="placeholder"
    :message-type="hasError ? 'error' : 'info'"
    @update:model-value="setText"
  />
</template>
