<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useWorkflowLookups } from '../../useWorkflowLookups';
import { STATIC_FIELDS, fieldLabelKey, freePrefixOf } from '../../fields';

const props = defineProps({
  modelValue: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const { lookups } = useWorkflowLookups();

const groupLabel = group =>
  t(`AUTOMATION.WORKFLOWS.FIELD_GROUPS.${group.toUpperCase()}`);

const options = computed(() =>
  [...STATIC_FIELDS, ...lookups.value.customFields].map(field => ({
    value: field.key,
    label: `${groupLabel(field.group)} › ${field.label || t(fieldLabelKey(field.key))}`,
  }))
);

const prefix = computed(() => freePrefixOf(props.modelValue));
const selected = computed(() => prefix.value || props.modelValue);
const suffix = computed(() => props.modelValue.slice(prefix.value.length));
</script>

<template>
  <div class="flex flex-col gap-2">
    <ComboBox
      :model-value="selected"
      :options="options"
      :display-label="modelValue"
      :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.FIELD_PLACEHOLDER')"
      :search-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SEARCH')"
      @update:model-value="emit('update:modelValue', $event)"
    />
    <Input
      v-if="prefix"
      :model-value="suffix"
      size="sm"
      :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.FREE_FIELD_PLACEHOLDER')"
      @update:model-value="emit('update:modelValue', prefix + $event)"
    />
  </div>
</template>
