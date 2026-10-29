<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { useWorkflowLookups } from '../../useWorkflowLookups';
import { TEMPLATE_VARIABLES } from '../../constants';
import { fieldLabelKey } from '../../fields';

const props = defineProps({
  modelValue: { type: String, default: '' },
  multiline: { type: Boolean, default: false },
  placeholder: { type: String, default: '' },
  // Variables are not offered for plain values (e.g. the name of a variable).
  plain: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const MAX_LENGTH = 4000;

const { t } = useI18n();
const { lookups } = useWorkflowLookups();

const rootRef = ref(null);
const showVariables = ref(false);

const variableGroups = computed(() => {
  const customOf = group =>
    lookups.value.customFields
      .filter(field => field.group === group)
      .map(field => ({ token: `{{${field.key}}}`, label: field.label }));
  const free = {
    trigger: [
      {
        token: '{{trigger.payload.}}',
        label: t(fieldLabelKey('trigger.payload.')),
      },
    ],
    vars: [{ token: '{{vars.}}', label: t(fieldLabelKey('vars.')) }],
  };
  const groups = TEMPLATE_VARIABLES.map(({ group, keys }) => ({
    group,
    items: [
      ...keys.map(key => ({
        token: `{{${key}}}`,
        label: t(fieldLabelKey(key)),
      })),
      ...customOf(group),
      ...(free[group] || []),
    ],
  }));
  return [...groups, { group: 'vars', items: free.vars }];
});

const insert = token => {
  const element = rootRef.value?.querySelector(
    props.multiline ? 'textarea' : 'input'
  );
  const text = props.modelValue || '';
  const start = element?.selectionStart ?? text.length;
  const end = element?.selectionEnd ?? text.length;
  emit(
    'update:modelValue',
    `${text.slice(0, start)}${token}${text.slice(end)}`
  );
  showVariables.value = false;
  // Tokens ending in "." wait for the user to type the rest of the path inside the braces.
  const caret = start + token.length - (token.endsWith('.}}') ? 2 : 0);
  nextTick(() => {
    element?.focus();
    element?.setSelectionRange(caret, caret);
  });
};
</script>

<template>
  <div ref="rootRef" class="relative flex flex-col gap-1.5">
    <TextArea
      v-if="multiline"
      :model-value="modelValue"
      :placeholder="placeholder"
      :max-length="MAX_LENGTH"
      auto-height
      min-height="5rem"
      @update:model-value="emit('update:modelValue', $event)"
    />
    <Input
      v-else
      :model-value="modelValue"
      size="sm"
      :placeholder="placeholder"
      @update:model-value="emit('update:modelValue', $event)"
    />
    <OnClickOutside v-if="!plain" @trigger="showVariables = false">
      <div class="flex justify-end">
        <Button
          ghost
          slate
          xs
          type="button"
          icon="i-lucide-braces"
          :label="t('AUTOMATION.WORKFLOWS.INSPECTOR.INSERT_VARIABLE')"
          @click="showVariables = !showVariables"
        />
      </div>
      <div
        v-if="showVariables"
        class="absolute end-0 z-30 w-64 p-2 mt-1 overflow-y-auto rounded-xl shadow-lg top-full max-h-72 bg-n-solid-2 outline outline-1 outline-n-container"
      >
        <div v-for="group in variableGroups" :key="group.group" class="mb-2">
          <p class="px-2 mb-1 text-xs font-medium uppercase text-n-slate-10">
            {{
              t(
                `AUTOMATION.WORKFLOWS.FIELD_GROUPS.${group.group.toUpperCase()}`
              )
            }}
          </p>
          <button
            v-for="item in group.items"
            :key="item.token"
            type="button"
            class="flex items-center justify-between w-full gap-2 px-2 py-1.5 text-sm text-start rounded-md text-n-slate-12 hover:bg-n-alpha-2"
            @click="insert(item.token)"
          >
            <span class="truncate">{{ item.label }}</span>
            <span class="text-xs text-n-slate-10 shrink-0">{{
              item.token
            }}</span>
          </button>
        </div>
      </div>
    </OnClickOutside>
  </div>
</template>
