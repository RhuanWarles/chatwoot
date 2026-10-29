<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import FieldPicker from './FieldPicker.vue';
import InspectorField from './InspectorField.vue';
import ValueInput from './ValueInput.vue';
import { useWorkflowLookups } from '../../useWorkflowLookups';
import { valueOptionsFor } from '../../valueOptions';
import { freePrefixOf } from '../../fields';
import { newId } from '../../graph';

const props = defineProps({
  modelValue: { type: Object, required: true },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const { lookups } = useWorkflowLookups();

const update = patch =>
  emit('update:modelValue', { ...props.modelValue, ...patch });

const choices = computed(
  () => valueOptionsFor(props.modelValue.field, lookups.value) || []
);
const isLostReason = computed(
  () => props.modelValue.field === 'deal.lost_reason_id'
);

const changeField = field => {
  const previous = freePrefixOf(props.modelValue.field);
  const sameFreeField = previous && previous === freePrefixOf(field);
  // Case values only mean something for the field they were picked for.
  update(sameFreeField ? { field } : { field, cases: [] });
};

const setCase = (index, patch) =>
  update({
    cases: props.modelValue.cases.map((item, position) =>
      position === index ? { ...item, ...patch } : item
    ),
  });

const removeCase = index =>
  update({
    cases: props.modelValue.cases.filter(
      (item, position) => position !== index
    ),
  });

const addCase = () =>
  update({
    cases: [
      ...props.modelValue.cases,
      { id: newId('case'), value: '', label: '' },
    ],
  });

const addOneCasePerChoice = () => {
  const used = props.modelValue.cases.map(item => String(item.value));
  const added = choices.value
    .filter(option => !used.includes(option.value))
    .map(option => ({
      id: newId('case'),
      value: option.value,
      label: option.label,
    }));
  update({ cases: [...props.modelValue.cases, ...added] });
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <InspectorField :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.SWITCH_FIELD')">
      <FieldPicker
        :model-value="modelValue.field"
        @update:model-value="changeField"
      />
    </InspectorField>
    <div
      v-for="(item, index) in modelValue.cases"
      :key="item.id"
      class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-1"
    >
      <div class="flex items-start gap-2">
        <div class="flex-1 min-w-0">
          <ValueInput
            :field="modelValue.field"
            :model-value="item.value"
            @update:model-value="setCase(index, { value: $event })"
          />
        </div>
        <Button
          ghost
          slate
          sm
          icon="i-lucide-trash-2"
          :aria-label="t('AUTOMATION.WORKFLOWS.INSPECTOR.REMOVE')"
          @click="removeCase(index)"
        />
      </div>
      <Input
        :model-value="item.label || ''"
        size="sm"
        :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.CASE_LABEL')"
        @update:model-value="setCase(index, { label: $event })"
      />
    </div>
    <div class="flex flex-col gap-2">
      <Button
        faded
        slate
        sm
        icon="i-lucide-plus"
        :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.ADD_CASE')"
        @click="addCase"
      />
      <Button
        v-if="choices.length"
        faded
        blue
        sm
        icon="i-lucide-list-plus"
        :label="
          isLostReason
            ? t('AUTOMATION.WORKFLOWS.INSPECTOR.ADD_CASE_PER_REASON')
            : t('AUTOMATION.WORKFLOWS.INSPECTOR.ADD_CASE_PER_OPTION')
        "
        @click="addOneCasePerChoice"
      />
    </div>
    <p class="mb-0 text-xs text-n-slate-10">
      {{ t('AUTOMATION.WORKFLOWS.INSPECTOR.SWITCH_HINT') }}
    </p>
  </div>
</template>
