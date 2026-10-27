<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import { ACTION_TYPES } from './automationHelpers';

const props = defineProps({
  index: { type: Number, required: true },
  total: { type: Number, required: true },
  type: { type: String, required: true },
  summary: { type: String, default: '' },
  valid: { type: Boolean, default: true },
  defaultExpanded: { type: Boolean, default: false },
  cardId: { type: String, required: true },
});
const emit = defineEmits(['move', 'remove']);

const { t } = useI18n();
const toggle = ref(null);
const expanded = ref(props.defaultExpanded || !props.valid);
const showErrors = ref(!props.defaultExpanded);

defineExpose({ focus: () => toggle.value?.focus() });
</script>

<template>
  <li
    class="rounded-2xl border bg-n-surface-1 shadow-sm"
    :class="valid ? 'border-n-container' : 'border-n-ruby-8'"
  >
    <div class="flex flex-wrap items-center gap-1 p-2">
      <button
        ref="toggle"
        type="button"
        class="flex flex-1 basis-48 min-w-0 items-center gap-3 p-1 text-start rounded-lg outline-none hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-expanded="expanded"
        :aria-controls="cardId"
        @click="expanded = !expanded"
      >
        <span
          class="grid shrink-0 size-6 place-items-center rounded-full bg-n-alpha-2 text-label-small text-n-slate-12"
        >
          {{ index + 1 }}
        </span>
        <span
          class="grid shrink-0 size-8 place-items-center rounded-lg bg-n-alpha-2 text-n-slate-11"
        >
          <Icon :icon="ACTION_TYPES[type].icon" class="size-4" />
        </span>
        <span class="flex flex-col flex-1 min-w-0">
          <span class="truncate text-heading-3 text-n-slate-12">
            {{ t(ACTION_TYPES[type].labelKey) }}
          </span>
          <span class="truncate text-body-main text-n-slate-11">
            {{ summary }}
          </span>
        </span>
        <Icon
          icon="i-lucide-chevron-down"
          class="size-4 shrink-0 transition-transform"
          :class="{ 'rotate-180': expanded }"
        />
      </button>
      <Label
        v-if="!valid"
        color="amber"
        compact
        :label="t('CRM.AUTOMATION_INCOMPLETE')"
      />
      <Button
        type="button"
        variant="ghost"
        color="slate"
        size="xs"
        icon="i-lucide-arrow-up"
        :disabled="index === 0"
        :aria-label="t('CRM.AUTOMATION_MOVE_UP')"
        @click="emit('move', -1)"
      />
      <Button
        type="button"
        variant="ghost"
        color="slate"
        size="xs"
        icon="i-lucide-arrow-down"
        :disabled="index === total - 1"
        :aria-label="t('CRM.AUTOMATION_MOVE_DOWN')"
        @click="emit('move', 1)"
      />
      <Button
        type="button"
        variant="ghost"
        color="ruby"
        size="xs"
        icon="i-lucide-trash-2"
        :aria-label="t('CRM.AUTOMATION_REMOVE')"
        @click="emit('remove')"
      />
    </div>
    <div
      v-if="expanded"
      :id="cardId"
      class="p-4 border-t border-n-weak"
      @focusout="showErrors = true"
    >
      <slot :show-errors="showErrors" />
    </div>
  </li>
</template>
