<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import ConditionRow from './ConditionRow.vue';
import InspectorField from './InspectorField.vue';
import SelectField from './SelectField.vue';
import { MATCH_MODES, optionLabelKey } from '../../constants';
import { emptyCondition } from '../../graph';

const props = defineProps({
  modelValue: { type: Object, required: true },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const matchOptions = computed(() =>
  MATCH_MODES.map(mode => ({
    value: mode,
    label: t(optionLabelKey('MATCH', mode)),
  }))
);

const update = patch =>
  emit('update:modelValue', { ...props.modelValue, ...patch });

const setCondition = (index, condition) =>
  update({
    conditions: props.modelValue.conditions.map((item, position) =>
      position === index ? condition : item
    ),
  });

const removeCondition = index =>
  update({
    conditions: props.modelValue.conditions.filter(
      (item, position) => position !== index
    ),
  });
</script>

<template>
  <div class="flex flex-col gap-4">
    <InspectorField :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.MATCH')">
      <SelectField
        :model-value="modelValue.match"
        :options="matchOptions"
        @update:model-value="update({ match: $event })"
      />
    </InspectorField>
    <ConditionRow
      v-for="(condition, index) in modelValue.conditions"
      :key="index"
      :model-value="condition"
      :can-remove="modelValue.conditions.length > 1"
      @update:model-value="setCondition(index, $event)"
      @remove="removeCondition(index)"
    />
    <Button
      faded
      slate
      sm
      icon="i-lucide-plus"
      :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.ADD_CONDITION')"
      @click="
        update({ conditions: [...modelValue.conditions, emptyCondition()] })
      "
    />
    <p class="mb-0 text-xs text-n-slate-10">
      {{ t('AUTOMATION.WORKFLOWS.INSPECTOR.CONDITION_HINT') }}
    </p>
  </div>
</template>
