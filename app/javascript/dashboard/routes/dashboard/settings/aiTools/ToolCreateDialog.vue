<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiToolsAPI from 'dashboard/api/aiTools';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { METHOD_OPTIONS, newTool, validHttpUrl } from './form';

const emit = defineEmits(['created']);

const { t } = useI18n();
const dialog = ref(null);
const busy = ref(false);
const error = ref('');
const draft = ref(newTool());

// The same fields the editor already requires before a tool can be saved.
const canSave = computed(() =>
  Boolean(
    draft.value.name.trim() &&
      draft.value.description.trim() &&
      validHttpUrl(draft.value.configuration.url)
  )
);

const open = () => {
  error.value = '';
  draft.value = newTool();
  dialog.value.open();
};

const create = async () => {
  if (!canSave.value || busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    const { data } = await aiToolsAPI.create({
      ai_tool: {
        name: draft.value.name,
        description: draft.value.description,
        active: draft.value.active,
        allow_in_playground: draft.value.allow_in_playground,
        configuration: draft.value.configuration,
      },
    });
    dialog.value.close();
    emit('created', data);
  } catch (createError) {
    error.value =
      createError.response?.data?.message || t('AI_TOOLS.SAVE_ERROR');
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
    :title="t('AI_TOOLS.CREATE')"
    :is-loading="busy"
    :disable-confirm-button="!canSave || busy"
    :confirm-button-label="t('AI_TOOLS.CREATE_CONFIRM')"
    :cancel-button-label="t('AI_TOOLS.CANCEL')"
    @confirm="create"
  >
    <div class="flex flex-col gap-4 p-1">
      <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.CREATE_HELP') }}</p>
      <p v-if="error" role="alert" class="text-sm text-n-ruby-9">
        {{ error }}
      </p>
      <Input
        v-model="draft.name"
        :label="t('AI_TOOLS.NAME')"
        :placeholder="t('AI_TOOLS.NAME_PLACEHOLDER')"
        :message="t('AI_TOOLS.NAME_HELP')"
        :disabled="busy"
      />
      <TextArea
        v-model="draft.description"
        :label="t('AI_TOOLS.DESCRIPTION')"
        :placeholder="t('AI_TOOLS.DESCRIPTION_PLACEHOLDER')"
        :message="t('AI_TOOLS.DESCRIPTION_HELP')"
        :max-length="1000"
        :show-character-count="false"
        :disabled="busy"
        auto-height
      />
      <div class="grid grid-cols-1 gap-4 md:grid-cols-[10rem_1fr]">
        <ComboBox
          v-model="draft.configuration.method"
          :label="t('AI_TOOLS.METHOD')"
          :options="METHOD_OPTIONS"
          :disabled="busy"
        />
        <Input
          v-model="draft.configuration.url"
          :label="t('AI_TOOLS.URL')"
          :placeholder="t('AI_TOOLS.URL_PLACEHOLDER')"
          :message="t('AI_TOOLS.URL_HELP')"
          :disabled="busy"
        />
      </div>
    </div>
  </Dialog>
</template>
