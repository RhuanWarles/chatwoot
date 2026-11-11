<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/knowledgeBases';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { DEFAULTS } from './form';

const emit = defineEmits(['created']);

const { t } = useI18n();
const dialog = ref(null);
const busy = ref(false);
const error = ref('');
const draft = ref({ ...DEFAULTS });

// The name is the only field that was already required to save a base.
const canSave = computed(() => Boolean(draft.value.name.trim()));

const open = () => {
  error.value = '';
  draft.value = { ...DEFAULTS };
  dialog.value.open();
};

const create = async () => {
  if (!canSave.value || busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    const { data } = await api.create({
      knowledge_base: { ...draft.value, description: draft.value.description },
    });
    dialog.value.close();
    emit('created', data);
  } catch {
    error.value = t('KNOWLEDGE.ERROR');
  } finally {
    busy.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="2xl"
    overflow-y-auto
    :title="t('KNOWLEDGE.CREATE_TITLE')"
    :is-loading="busy"
    :disable-confirm-button="!canSave || busy"
    :confirm-button-label="t('KNOWLEDGE.CREATE_CONFIRM')"
    :cancel-button-label="t('KNOWLEDGE.CANCEL')"
    @confirm="create"
  >
    <div class="flex flex-col gap-4 p-1">
      <p class="text-sm text-n-slate-11">{{ t('KNOWLEDGE.CREATE_HELP') }}</p>
      <p v-if="error" role="alert" class="text-sm text-n-ruby-11">
        {{ error }}
      </p>
      <Input
        v-model="draft.name"
        :label="t('KNOWLEDGE.NAME')"
        :max-length="100"
        :disabled="busy"
      />
      <TextArea
        v-model="draft.description"
        :label="t('KNOWLEDGE.DESCRIPTION')"
        :max-length="2000"
        :disabled="busy"
        auto-height
      />
    </div>
  </Dialog>
</template>
