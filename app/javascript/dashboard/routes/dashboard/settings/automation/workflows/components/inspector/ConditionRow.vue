<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import FieldPicker from './FieldPicker.vue';
import SelectField from './SelectField.vue';
import ValueInput from './ValueInput.vue';
import { OPERATORS, OPERATOR_BY_KEY, operatorLabelKey } from '../../constants';
import { freePrefixOf } from '../../fields';

const props = defineProps({
  modelValue: { type: Object, required: true },
  canRemove: { type: Boolean, default: true },
});

const emit = defineEmits(['update:modelValue', 'remove']);

const { t } = useI18n();

const operatorOptions = computed(() =>
  OPERATORS.map(item => ({
    value: item.key,
    label: t(operatorLabelKey(item.key)),
  }))
);

const operator = computed(() => OPERATOR_BY_KEY[props.modelValue.operator]);

const update = patch =>
  emit('update:modelValue', { ...props.modelValue, ...patch });

const emptyValue = multi => (multi ? [] : '');

const changeField = field => {
  const previous = freePrefixOf(props.modelValue.field);
  // Typing the tail of a webhook path or variable name keeps the value; anything else restarts it.
  const sameFreeField = previous && previous === freePrefixOf(field);
  update(
    sameFreeField
      ? { field }
      : { field, value: emptyValue(operator.value?.multi) }
  );
};

const changeOperator = key => {
  const next = OPERATOR_BY_KEY[key];
  const current = props.modelValue.value;
  let value = current;
  if (next.noValue) value = '';
  else if (next.multi && !Array.isArray(current))
    value = current === '' ? [] : [current];
  else if (!next.multi && Array.isArray(current)) value = current[0] ?? '';
  update({ operator: key, value });
};
</script>

<template>
  <div class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-1">
    <div class="flex items-start gap-2">
      <div class="flex-1 min-w-0">
        <FieldPicker
          :model-value="modelValue.field"
          @update:model-value="changeField"
        />
      </div>
      <Button
        v-if="canRemove"
        ghost
        slate
        sm
        icon="i-lucide-trash-2"
        :aria-label="t('AUTOMATION.WORKFLOWS.INSPECTOR.REMOVE')"
        @click="emit('remove')"
      />
    </div>
    <SelectField
      :model-value="modelValue.operator"
      :options="operatorOptions"
      @update:model-value="changeOperator"
    />
    <ValueInput
      v-if="!operator?.noValue"
      :field="modelValue.field"
      :multi="Boolean(operator?.multi)"
      :model-value="modelValue.value"
      @update:model-value="update({ value: $event })"
    />
  </div>
</template>
