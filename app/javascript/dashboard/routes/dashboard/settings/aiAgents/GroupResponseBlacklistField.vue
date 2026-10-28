<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { normalizeGroupPhone } from './form';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  enabled: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
});
const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const number = ref('');
const error = ref('');

const addNumber = () => {
  const normalized = normalizeGroupPhone(number.value);
  if (!normalized) {
    error.value = t('AI_AGENTS.GROUP_BLACKLIST_INVALID');
    return;
  }
  if (props.modelValue.includes(normalized)) {
    error.value = t('AI_AGENTS.GROUP_BLACKLIST_DUPLICATE');
    return;
  }
  emit('update:modelValue', [...props.modelValue, normalized]);
  number.value = '';
  error.value = '';
};

const removeNumber = value => {
  emit(
    'update:modelValue',
    props.modelValue.filter(item => item !== value)
  );
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <p class="text-sm text-n-slate-12">
      {{ t('AI_AGENTS.GROUP_BLACKLIST_LABEL') }}
    </p>
    <p class="text-xs text-n-slate-11">
      {{ t('AI_AGENTS.GROUP_BLACKLIST_HELP') }}
    </p>
    <p v-if="!enabled" class="text-xs text-n-slate-11">
      {{ t('AI_AGENTS.GROUP_BLACKLIST_DISABLED') }}
    </p>
    <ul v-if="modelValue.length" class="flex flex-col gap-2">
      <li
        v-for="phone in modelValue"
        :key="phone"
        class="flex items-center justify-between gap-2 text-sm text-n-slate-12"
      >
        <span dir="ltr">{{ `+${phone}` }}</span>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          icon="i-lucide-x"
          :aria-label="t('AI_AGENTS.GROUP_BLACKLIST_REMOVE', { number: phone })"
          :disabled="disabled || !enabled"
          @click="removeNumber(phone)"
        />
      </li>
    </ul>
    <div class="flex items-start gap-2">
      <Input
        v-model="number"
        type="tel"
        class="flex-1"
        :label="t('AI_AGENTS.GROUP_BLACKLIST_NUMBER')"
        :placeholder="t('AI_AGENTS.GROUP_BLACKLIST_PLACEHOLDER')"
        :disabled="disabled || !enabled"
        :message="error"
        :message-type="error ? 'error' : 'info'"
        @enter="addNumber"
      />
      <Button
        type="button"
        variant="faded"
        :label="t('AI_AGENTS.GROUP_BLACKLIST_ADD')"
        :disabled="disabled || !enabled"
        @click="addNumber"
      />
    </div>
  </div>
</template>
