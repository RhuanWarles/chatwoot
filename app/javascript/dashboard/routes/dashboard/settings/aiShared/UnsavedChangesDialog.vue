<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const { t } = useI18n();
const dialogRef = ref(null);
let answer = null;

const resolveAnswer = value => {
  answer?.(value);
  answer = null;
};

// Resolves `true` when the person chooses to leave and `false` when they keep editing.
const ask = () => {
  resolveAnswer(false);
  return new Promise(resolve => {
    answer = resolve;
    dialogRef.value?.open();
  });
};

const confirmLeave = () => {
  resolveAnswer(true);
  dialogRef.value?.close();
};

defineExpose({ ask });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    :title="t('AI_HUB.UNSAVED_TITLE')"
    :description="t('AI_HUB.UNSAVED_CONFIRM')"
    :confirm-button-label="t('AI_HUB.UNSAVED_LEAVE')"
    :cancel-button-label="t('AI_HUB.UNSAVED_STAY')"
    @confirm="confirmLeave"
    @close="resolveAnswer(false)"
  />
</template>
