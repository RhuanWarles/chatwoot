<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import MultiValueInput from './MultiValueInput.vue';
import { useWorkflowLookups } from '../../useWorkflowLookups';
import { valueOptionsFor } from '../../valueOptions';
import { FIELD_KINDS, fieldKindOf } from '../../fields';

const props = defineProps({
  field: { type: String, default: '' },
  multi: { type: Boolean, default: false },
  modelValue: { type: [String, Number, Array], default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const { lookups } = useWorkflowLookups();

const options = computed(() => valueOptionsFor(props.field, lookups.value));
const isNumber = computed(
  () =>
    fieldKindOf(props.field, lookups.value.customFields) === FIELD_KINDS.NUMBER
);
const list = computed(() => {
  if (Array.isArray(props.modelValue)) return props.modelValue;
  return props.modelValue === '' ? [] : [props.modelValue];
});
const single = computed(() => String(props.modelValue ?? ''));
</script>

<template>
  <MultiValueInput
    v-if="multi"
    :model-value="list"
    :options="options"
    :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.VALUES_PLACEHOLDER')"
    @update:model-value="emit('update:modelValue', $event)"
  />
  <ComboBox
    v-else-if="options"
    :model-value="single"
    :options="options"
    :display-label="single"
    :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.VALUE_PLACEHOLDER')"
    :search-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SEARCH')"
    @update:model-value="emit('update:modelValue', $event)"
  />
  <Input
    v-else
    :model-value="single"
    :type="isNumber ? 'number' : 'text'"
    size="sm"
    :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.VALUE_PLACEHOLDER')"
    @update:model-value="emit('update:modelValue', $event)"
  />
</template>
