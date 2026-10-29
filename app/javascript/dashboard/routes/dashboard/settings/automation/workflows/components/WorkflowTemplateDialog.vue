<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  WORKFLOW_TEMPLATES,
  templateDescriptionKey,
  templateNameKey,
} from '../templates';

defineProps({
  isCreating: { type: Boolean, default: false },
});

const emit = defineEmits(['pick']);

const { t } = useI18n();
const dialogRef = ref(null);

defineExpose({
  open: () => dialogRef.value?.open(),
  close: () => dialogRef.value?.close(),
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    :title="t('AUTOMATION.WORKFLOWS.TEMPLATES.TITLE')"
    :description="t('AUTOMATION.WORKFLOWS.TEMPLATES.DESCRIPTION')"
    :show-confirm-button="false"
    :show-cancel-button="false"
    show-close-button
  >
    <div class="grid gap-3 sm:grid-cols-2">
      <button
        v-for="template in WORKFLOW_TEMPLATES"
        :key="template.key"
        type="button"
        :disabled="isCreating"
        class="flex items-start gap-3 p-4 text-start rounded-xl outline outline-1 outline-n-weak hover:bg-n-alpha-1 disabled:opacity-60"
        @click="emit('pick', template)"
      >
        <Icon
          :icon="template.icon"
          class="mt-0.5 size-5 shrink-0 text-n-blue-11"
        />
        <div class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t(templateNameKey(template.key)) }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t(templateDescriptionKey(template.key)) }}
          </span>
        </div>
      </button>
    </div>
  </Dialog>
</template>
