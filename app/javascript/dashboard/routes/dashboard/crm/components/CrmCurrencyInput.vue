<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import { brlFormatter as formatter } from './currencyHelpers';

const props = defineProps({
  modelValue: { type: [Number, String], default: '' },
  label: { type: String, default: '' },
});
const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const display = ref('');
const focused = ref(false);
const error = ref(false);

const updateDisplay = () => {
  display.value =
    props.modelValue === '' || props.modelValue == null
      ? ''
      : formatter.format(Number(props.modelValue));
};
watch(
  () => props.modelValue,
  () => {
    if (!focused.value) updateDisplay();
  },
  { immediate: true }
);

const onFocus = () => {
  focused.value = true;
  display.value =
    props.modelValue === '' || props.modelValue == null
      ? ''
      : Number(props.modelValue).toFixed(2).replace('.', ',');
};
const onInput = value => {
  display.value = value;
  const text = value
    .trim()
    .replace(/^R\$\s*/, '')
    .replace(/\s/g, '');
  if (!text) {
    error.value = false;
    emit('update:modelValue', '');
    return;
  }
  // Accept plain digits or the Brazilian decimal/thousands separators.
  const valid = /^(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,\d{0,2})?$/.test(text);
  error.value = !valid;
  if (valid)
    emit(
      'update:modelValue',
      Number(text.replace(/\./g, '').replace(',', '.'))
    );
};
const onBlur = () => {
  focused.value = false;
  if (!error.value) updateDisplay();
};
defineExpose({ isInvalid: error });
</script>

<template>
  <Input
    :model-value="display"
    :label="label || t('CRM.VALUE')"
    :placeholder="formatter.format(0)"
    inputmode="decimal"
    :message="error ? t('CRM.VALUE_INVALID') : ''"
    :message-type="error ? 'error' : 'info'"
    @update:model-value="onInput"
    @focus="onFocus"
    @blur="onBlur"
  />
</template>
