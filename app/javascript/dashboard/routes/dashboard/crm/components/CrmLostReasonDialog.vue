<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

defineProps({
  reasons: { type: Array, required: true },
});

const emit = defineEmits(['confirm', 'cancel']);

const NOTE_MAX_LENGTH = 500;

const { t } = useI18n();
const dialog = ref(null);
const selectedId = ref(null);
const note = ref('');
let confirmed = false;

const confirm = () => {
  if (!selectedId.value) return;
  confirmed = true;
  dialog.value.close();
  emit('confirm', {
    lost_reason_id: selectedId.value,
    lost_note: note.value.trim() || null,
  });
};
// The dialog also closes after a confirmation, and only a dismissal is a cancellation.
const onClose = () => {
  if (!confirmed) emit('cancel');
};

onMounted(() => dialog.value.open());
</script>

<template>
  <Dialog
    ref="dialog"
    type="alert"
    width="md"
    overflow-y-auto
    :title="t('CRM.LOST_REASON_DIALOG_TITLE')"
    :description="t('CRM.LOST_REASON_DIALOG_DESCRIPTION')"
    :confirm-button-label="t('CRM.LOST_REASON_CONFIRM')"
    :disable-confirm-button="!selectedId"
    @confirm="confirm"
    @close="onClose"
  >
    <fieldset
      class="m-0 flex min-w-0 flex-col gap-2 border-0 p-0"
      data-test="lost-reasons"
    >
      <legend class="mb-2 p-0 text-sm font-medium text-n-slate-12">
        {{ t('CRM.LOST_REASON') }}
      </legend>
      <label
        v-for="reason in reasons"
        :key="reason.id"
        class="flex cursor-pointer items-center gap-3 rounded-lg border px-3 py-2 text-sm text-n-slate-12"
        :class="
          selectedId === reason.id
            ? 'border-n-ruby-8 bg-n-ruby-3'
            : 'border-n-weak bg-n-solid-1 hover:bg-n-alpha-2'
        "
        data-test="lost-reason"
      >
        <input
          v-model="selectedId"
          type="radio"
          name="lost-reason"
          class="shrink-0"
          :value="reason.id"
        />
        <span class="min-w-0 break-words">{{ reason.name }}</span>
      </label>
    </fieldset>
    <TextArea
      v-model="note"
      :label="t('CRM.LOST_NOTE')"
      :placeholder="t('CRM.LOST_NOTE_PLACEHOLDER')"
      :max-length="NOTE_MAX_LENGTH"
      show-character-count
    />
  </Dialog>
</template>
