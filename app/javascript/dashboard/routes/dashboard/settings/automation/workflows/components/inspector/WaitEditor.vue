<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import InspectorField from './InspectorField.vue';
import SelectField from './SelectField.vue';
import { WAIT_UNITS, optionLabelKey } from '../../constants';

const props = defineProps({
  modelValue: { type: Object, required: true },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const unitOptions = computed(() =>
  WAIT_UNITS.map(unit => ({
    value: unit,
    label: t(optionLabelKey('WAIT_UNIT', unit)),
  }))
);

const update = patch =>
  emit('update:modelValue', { ...props.modelValue, ...patch });
const changeAmount = value =>
  update({ amount: value === '' ? '' : Number(value) });
</script>

<template>
  <div class="flex flex-col gap-4">
    <InspectorField :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.WAIT_AMOUNT')">
      <Input
        :model-value="modelValue.amount"
        type="number"
        min="1"
        size="sm"
        @update:model-value="changeAmount"
      />
    </InspectorField>
    <InspectorField :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.WAIT_UNIT')">
      <SelectField
        :model-value="modelValue.unit"
        :options="unitOptions"
        @update:model-value="update({ unit: $event })"
      />
    </InspectorField>
    <p class="mb-0 text-xs text-n-slate-10">
      {{ t('AUTOMATION.WORKFLOWS.INSPECTOR.WAIT_HINT') }}
    </p>
  </div>
</template>
