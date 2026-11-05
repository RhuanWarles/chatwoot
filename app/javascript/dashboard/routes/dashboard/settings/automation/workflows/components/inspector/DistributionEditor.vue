<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import {
  DISTRIBUTION_TOTAL,
  distributionTotal,
  evenShares,
} from '../../distribution';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  // The people to choose from, as { value, label }.
  agents: { type: Array, default: () => [] },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const total = computed(() => distributionTotal(props.modelValue));
const remaining = computed(() => DISTRIBUTION_TOTAL - total.value);
const taken = computed(
  () => new Set(props.modelValue.map(row => String(row.user_id)))
);

// A person already in the list is not offered again, except in their own row.
const optionsFor = row =>
  props.agents.filter(
    agent =>
      String(agent.value) === String(row.user_id) ||
      !taken.value.has(String(agent.value))
  );

const status = computed(() => {
  if (remaining.value === 0) {
    return {
      tone: 'text-n-teal-11',
      text: t('AUTOMATION.WORKFLOWS.INSPECTOR.DISTRIBUTION_TOTAL', {
        total: total.value,
      }),
    };
  }
  const key =
    remaining.value > 0 ? 'DISTRIBUTION_MISSING' : 'DISTRIBUTION_OVER';
  return {
    tone: 'text-n-ruby-11',
    text: t(`AUTOMATION.WORKFLOWS.INSPECTOR.${key}`, {
      n: Math.abs(remaining.value),
    }),
  };
});

const setRow = (index, patch) =>
  emit(
    'update:modelValue',
    props.modelValue.map((row, position) =>
      position === index ? { ...row, ...patch } : row
    )
  );

const setPercentage = (index, raw) =>
  setRow(index, { percentage: raw === '' ? '' : Math.trunc(Number(raw)) });

const removeRow = index =>
  emit(
    'update:modelValue',
    props.modelValue.filter((row, position) => position !== index)
  );

const addRow = () =>
  emit('update:modelValue', [
    ...props.modelValue,
    { user_id: '', percentage: remaining.value > 0 ? remaining.value : 1 },
  ]);

const splitEvenly = () => {
  const shares = evenShares(props.modelValue.length);
  emit(
    'update:modelValue',
    props.modelValue.map((row, index) => ({
      ...row,
      percentage: shares[index],
    }))
  );
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="mb-0 text-xs text-n-slate-10">
      {{ t('AUTOMATION.WORKFLOWS.INSPECTOR.DISTRIBUTION_HINT') }}
    </p>
    <div
      v-for="(row, index) in modelValue"
      :key="index"
      class="flex items-start gap-2 p-3 rounded-lg bg-n-alpha-1"
      data-test="distribution-row"
    >
      <div class="flex-1 min-w-0">
        <ComboBox
          :model-value="row.user_id"
          :options="optionsFor(row)"
          :display-label="String(row.user_id)"
          :has-error="hasError && (row.user_id === '' || row.user_id == null)"
          :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.DISTRIBUTION_PERSON')"
          :search-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SEARCH')"
          @update:model-value="setRow(index, { user_id: $event })"
        />
      </div>
      <div class="flex items-center w-24 gap-1 shrink-0">
        <Input
          :model-value="row.percentage"
          type="number"
          min="1"
          max="100"
          size="sm"
          data-test="distribution-percentage"
          @update:model-value="setPercentage(index, $event)"
        />
        <span class="text-sm text-n-slate-11">%</span>
      </div>
      <Button
        ghost
        slate
        sm
        icon="i-lucide-trash-2"
        :aria-label="t('AUTOMATION.WORKFLOWS.INSPECTOR.REMOVE')"
        @click="removeRow(index)"
      />
    </div>
    <div class="flex flex-wrap items-center justify-between gap-2">
      <span
        class="text-sm font-medium"
        :class="status.tone"
        data-test="distribution-total"
      >
        {{ status.text }}
      </span>
      <div class="flex items-center gap-2">
        <Button
          faded
          slate
          sm
          icon="i-lucide-equal"
          :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.DISTRIBUTION_EVEN')"
          :disabled="!modelValue.length"
          @click="splitEvenly"
        />
        <Button
          faded
          slate
          sm
          icon="i-lucide-plus"
          :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.DISTRIBUTION_ADD')"
          @click="addRow"
        />
      </div>
    </div>
  </div>
</template>
