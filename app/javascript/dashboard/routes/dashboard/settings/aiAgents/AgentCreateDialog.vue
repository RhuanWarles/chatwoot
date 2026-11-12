<script setup>
import { computed, inject, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import voiceAgentsAPI from 'dashboard/api/voiceAgents';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { agentPayload, newAgent, validAgent } from './form';
import { newVoiceAgent, validVoiceAgent, voiceAgentPayload } from './voiceForm';
import { AGENTS_WORKSPACE } from './workspace';

const props = defineProps({
  type: {
    type: String,
    default: 'text',
  },
});

const emit = defineEmits(['created']);

const { t } = useI18n();
const workspace = inject(AGENTS_WORKSPACE);
const dialog = ref(null);
const busy = ref(false);
const error = ref('');
const textDraft = ref(newAgent());
const voiceDraft = ref(newVoiceAgent());

const isVoice = computed(() => props.type === 'voice');
const settings = computed(() => workspace.textSettings.value);
const configuredProvider = computed(
  () => settings.value?.provider || settings.value?.platform_provider || ''
);
const configuredModel = computed(
  () => settings.value?.model || settings.value?.platform_model || ''
);
const providers = computed(() => workspace.voiceMeta.value.providers);
const providerOptions = computed(() =>
  providers.value.map(value => ({
    value,
    label: value === 'vapi' ? 'Vapi' : value,
  }))
);
const canSave = computed(() =>
  isVoice.value
    ? validVoiceAgent(
        voiceDraft.value,
        providers.value,
        workspace.voiceMeta.value.durationRange
      )
    : validAgent(textDraft.value)
);

// The text provider and model come from the account's text connection, as in the editor.
const open = () => {
  error.value = '';
  textDraft.value = {
    ...newAgent(),
    provider: configuredProvider.value || 'openai',
    model: configuredModel.value,
  };
  voiceDraft.value = { ...newVoiceAgent(), provider: providers.value[0] };
  dialog.value.open();
};

const create = async () => {
  if (!canSave.value || busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    const { data } = isVoice.value
      ? await voiceAgentsAPI.create({
          voice_agent: voiceAgentPayload(voiceDraft.value),
        })
      : await aiAgentsAPI.create({ ai_agent: agentPayload(textDraft.value) });
    dialog.value.close();
    emit('created', data);
  } catch {
    error.value = t('AI_AGENTS.SAVE_ERROR');
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
    :title="isVoice ? t('AI_HUB.CREATE_VOICE') : t('AI_AGENTS.CREATE')"
    :is-loading="busy"
    :disable-confirm-button="!canSave || busy"
    :confirm-button-label="t('AI_AGENTS.CREATE_CONFIRM')"
    :cancel-button-label="t('AI_AGENTS.CANCEL')"
    @confirm="create"
  >
    <div class="flex flex-col gap-4 p-1">
      <p class="text-sm text-n-slate-11">{{ t('AI_AGENTS.CREATE_HELP') }}</p>
      <p v-if="error" role="alert" class="text-sm text-n-ruby-9">
        {{ error }}
      </p>
      <template v-if="isVoice">
        <Input
          v-model="voiceDraft.name"
          :label="t('AI_AGENTS.NAME')"
          :disabled="busy"
        />
        <Input
          v-model="voiceDraft.description"
          :label="t('AI_AGENTS.DESCRIPTION')"
          :disabled="busy"
        />
        <div class="flex flex-col gap-2">
          <label class="text-sm text-n-slate-12">{{
            t('AI_AGENTS.PROVIDER')
          }}</label>
          <ComboBox
            v-model="voiceDraft.provider"
            :options="providerOptions"
            :disabled="busy"
          />
        </div>
      </template>
      <template v-else>
        <Input
          v-model="textDraft.name"
          :label="t('AI_AGENTS.NAME')"
          :disabled="busy"
        />
        <Input
          v-model="textDraft.description"
          :label="t('AI_AGENTS.DESCRIPTION')"
          :disabled="busy"
        />
        <TextArea
          v-model="textDraft.system_prompt"
          :label="t('AI_AGENTS.PROMPT')"
          :message="t('AI_AGENTS.PROMPT_HELP')"
          :disabled="busy"
          auto-height
          min-height="10rem"
          max-height="20rem"
        />
        <p v-if="!configuredModel" class="text-xs text-n-amber-11">
          {{ t('AI_AGENTS.TEXT_CONFIGURATION_HELP') }}
        </p>
      </template>
    </div>
  </Dialog>
</template>
