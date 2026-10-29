<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import InspectorField from './InspectorField.vue';
import ParamField from './ParamField.vue';
import SelectField from './SelectField.vue';
import { ACTIONS, ACTION_BY_KEY, ACTION_GROUPS } from '../../actions';
import { actionLabelKey } from '../../constants';
import { defaultParams } from '../../graph';

const props = defineProps({
  modelValue: { type: Object, required: true },
  // Param keys the validation flagged for this node.
  invalidParams: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const definition = computed(() => ACTION_BY_KEY[props.modelValue.action]);
const params = computed(() => props.modelValue.params || {});

const groups = computed(() =>
  ACTION_GROUPS.map(group => ({
    label: t(`AUTOMATION.WORKFLOWS.ACTION_GROUPS.${group.toUpperCase()}`),
    options: ACTIONS.filter(item => item.group === group).map(item => ({
      value: item.key,
      label: t(actionLabelKey(item.key)),
    })),
  }))
);

const visibleParams = computed(() =>
  (definition.value?.params || []).filter(
    item => !item.showWhen || item.showWhen(params.value)
  )
);

const update = patch =>
  emit('update:modelValue', { ...props.modelValue, ...patch });

const changeAction = action =>
  update({ action, params: defaultParams(action) });

// Params that stop being visible (e.g. the lost reason after leaving "lost") are dropped so they
// are never sent by accident.
const updateParam = (key, value) => {
  const next = { ...params.value, [key]: value };
  if (key === 'pipeline_id') next.pipeline_stage_id = '';
  (definition.value?.params || []).forEach(item => {
    if (item.showWhen && !item.showWhen(next)) delete next[item.key];
  });
  update({ params: next });
};

const requiresKey = computed(() => definition.value?.requires);
</script>

<template>
  <div class="flex flex-col gap-4">
    <InspectorField :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.ACTION')">
      <SelectField
        :model-value="modelValue.action || ''"
        :groups="groups"
        :placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SELECT')"
        @update:model-value="changeAction"
      />
    </InspectorField>
    <p v-if="requiresKey" class="mb-0 text-xs text-n-slate-10">
      {{
        t(
          `AUTOMATION.WORKFLOWS.INSPECTOR.REQUIRES_${requiresKey.toUpperCase()}`
        )
      }}
    </p>
    <ParamField
      v-for="item in visibleParams"
      :key="`${modelValue.action}-${item.key}`"
      :action="modelValue.action"
      :definition="item"
      :params="params"
      :has-error="invalidParams.includes(item.key)"
      @update="updateParam"
    />
    <p
      v-if="definition?.atLeastOne && invalidParams.length === 0"
      class="mb-0 text-xs text-n-slate-10"
    >
      {{ t('AUTOMATION.WORKFLOWS.INSPECTOR.AT_LEAST_ONE') }}
    </p>
    <div
      v-if="definition"
      class="flex items-start gap-2 pt-2 border-t border-n-weak"
    >
      <Switch
        :model-value="Boolean(modelValue.continue_on_error)"
        @update:model-value="update({ continue_on_error: $event })"
      />
      <div class="flex flex-col min-w-0">
        <span class="text-sm text-n-slate-12">
          {{ t('AUTOMATION.WORKFLOWS.INSPECTOR.CONTINUE_ON_ERROR') }}
        </span>
        <span class="text-xs text-n-slate-10">
          {{ t('AUTOMATION.WORKFLOWS.INSPECTOR.CONTINUE_ON_ERROR_HINT') }}
        </span>
      </div>
    </div>
  </div>
</template>
