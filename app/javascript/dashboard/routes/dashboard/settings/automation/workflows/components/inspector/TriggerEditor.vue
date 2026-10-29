<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import InspectorField from './InspectorField.vue';
import SelectField from './SelectField.vue';
import {
  TRIGGER_EVENTS,
  TRIGGER_GROUPS,
  triggerLabelKey,
} from '../../constants';

const props = defineProps({
  modelValue: { type: Object, required: true },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const groups = computed(() =>
  TRIGGER_GROUPS.map(group => ({
    label: t(`AUTOMATION.WORKFLOWS.TRIGGER_GROUPS.${group.toUpperCase()}`),
    options: TRIGGER_EVENTS.filter(item => item.group === group).map(item => ({
      value: item.key,
      label: t(triggerLabelKey(item.key)),
    })),
  }))
);

const hint = computed(() =>
  t(
    `AUTOMATION.WORKFLOWS.TRIGGER_HINTS.${props.modelValue.event.toUpperCase()}`
  )
);
</script>

<template>
  <div class="flex flex-col gap-4">
    <InspectorField :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.TRIGGER_EVENT')">
      <SelectField
        :model-value="modelValue.event"
        :groups="groups"
        @update:model-value="
          emit('update:modelValue', { ...modelValue, event: $event })
        "
      />
    </InspectorField>
    <p class="mb-0 text-xs text-n-slate-10">{{ hint }}</p>
  </div>
</template>
