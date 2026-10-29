<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ActionEditor from './ActionEditor.vue';
import ConditionsEditor from './ConditionsEditor.vue';
import SwitchEditor from './SwitchEditor.vue';
import TriggerEditor from './TriggerEditor.vue';
import WaitEditor from './WaitEditor.vue';
import { NODE_TYPES, nodeIcon } from '../../constants';

const props = defineProps({
  node: { type: Object, default: null },
  issues: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:data', 'delete']);

const { t } = useI18n();

const EDITORS = {
  [NODE_TYPES.TRIGGER]: TriggerEditor,
  [NODE_TYPES.CONDITION]: ConditionsEditor,
  [NODE_TYPES.SWITCH]: SwitchEditor,
  [NODE_TYPES.WAIT]: WaitEditor,
  [NODE_TYPES.ACTION]: ActionEditor,
};

const editor = computed(() => EDITORS[props.node?.type]);
const invalidParams = computed(() =>
  props.issues.filter(issue => issue.param).map(issue => issue.param)
);
const issueMessages = computed(() =>
  [
    ...new Set(
      props.issues.filter(issue => !issue.param).map(issue => issue.code)
    ),
  ].map(code => t(`AUTOMATION.WORKFLOWS.VALIDATION.${code}`))
);
</script>

<template>
  <aside
    class="flex flex-col w-80 shrink-0 h-full overflow-y-auto border-s border-n-weak bg-n-solid-1"
  >
    <div
      v-if="!node"
      class="flex flex-col items-center justify-center flex-1 gap-3 px-8 text-center text-n-slate-11"
    >
      <Icon icon="i-lucide-mouse-pointer-click" class="size-8 text-n-slate-9" />
      <p class="mb-0 text-sm">
        {{ t('AUTOMATION.WORKFLOWS.INSPECTOR.EMPTY') }}
      </p>
    </div>
    <template v-else>
      <header
        class="flex items-center justify-between gap-2 px-4 py-3 border-b border-n-weak"
      >
        <div class="flex items-center min-w-0 gap-2 text-n-slate-12">
          <Icon :icon="nodeIcon(node)" class="size-4 shrink-0" />
          <h3 class="mb-0 text-sm font-medium truncate">
            {{
              t(`AUTOMATION.WORKFLOWS.NODE_TYPES.${node.type.toUpperCase()}`)
            }}
          </h3>
        </div>
        <Button
          ghost
          ruby
          sm
          icon="i-lucide-trash-2"
          :aria-label="t('AUTOMATION.WORKFLOWS.INSPECTOR.DELETE_NODE')"
          @click="emit('delete')"
        />
      </header>
      <div class="flex flex-col gap-4 p-4">
        <ul
          v-if="issueMessages.length"
          class="flex flex-col gap-1 p-3 mb-0 text-xs list-none rounded-lg bg-n-ruby-3 text-n-ruby-11"
        >
          <li v-for="message in issueMessages" :key="message">{{ message }}</li>
        </ul>
        <component
          :is="editor"
          :model-value="node.data"
          :invalid-params="invalidParams"
          @update:model-value="emit('update:data', $event)"
        />
      </div>
    </template>
  </aside>
</template>
