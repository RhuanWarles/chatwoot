<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import inboxesAPI from 'dashboard/api/inboxes';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SettingsAccordion from 'dashboard/components-next/Settings/SettingsAccordion.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const store = useStore();
const evolutionInstanceName = ref('');
const evolutionSignMessages = ref(false);
const savedEvolutionSignMessages = ref(false);
const evolutionSignMessagesAvailable = ref(false);
const isLoadingEvolutionConfiguration = ref(false);
const isUpdatingEvolutionInstance = ref(false);
const isUpdatingEvolutionSignMessages = ref(false);
const evolutionConfigurationError = ref('');

const setDefaults = () => {
  evolutionInstanceName.value =
    props.inbox.additional_attributes?.evolution_instance_name || '';
};

const loadEvolutionConfiguration = async () => {
  evolutionConfigurationError.value = '';
  evolutionSignMessagesAvailable.value = false;
  if (!evolutionInstanceName.value.trim() || !props.inbox.id) return;

  isLoadingEvolutionConfiguration.value = true;
  try {
    const response = await inboxesAPI.getEvolutionConfiguration(props.inbox.id);
    const { sign_msg: signMsg } = response.data;
    evolutionSignMessages.value = signMsg;
    savedEvolutionSignMessages.value = signMsg;
    evolutionSignMessagesAvailable.value = true;
  } catch (error) {
    evolutionConfigurationError.value = t(
      'INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_CONFIGURATION_ERROR'
    );
  } finally {
    isLoadingEvolutionConfiguration.value = false;
  }
};

const updateEvolutionInstance = async () => {
  isUpdatingEvolutionInstance.value = true;
  try {
    const additionalAttributes = {
      ...(props.inbox.additional_attributes || {}),
      evolution_instance_name: evolutionInstanceName.value.trim(),
    };
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      channel: { additional_attributes: additionalAttributes },
    });
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
    await loadEvolutionConfiguration();
  } catch (error) {
    useAlert(t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
  } finally {
    isUpdatingEvolutionInstance.value = false;
  }
};

const updateEvolutionSignMessages = async () => {
  if (!evolutionSignMessagesAvailable.value) return;

  isUpdatingEvolutionSignMessages.value = true;
  try {
    const response = await inboxesAPI.updateEvolutionConfiguration(
      props.inbox.id,
      evolutionSignMessages.value
    );
    const { sign_msg: signMsg } = response.data;
    evolutionSignMessages.value = signMsg;
    savedEvolutionSignMessages.value = signMsg;
  } catch (error) {
    evolutionSignMessages.value = savedEvolutionSignMessages.value;
    useAlert(
      t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_CONFIGURATION_UPDATE_ERROR')
    );
  } finally {
    isUpdatingEvolutionSignMessages.value = false;
  }
};

watch(
  () => props.inbox,
  () => {
    setDefaults();
    loadEvolutionConfiguration();
  },
  { deep: true, immediate: true }
);
</script>

<template>
  <SettingsAccordion
    :title="t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_API_TITLE')"
    class="mt-6"
  >
    <SettingsFieldSection
      :label="t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_INSTANCE_NAME')"
      :help-text="t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_INSTANCE_NAME_HELP')"
    >
      <div class="flex items-center gap-2">
        <input v-model="evolutionInstanceName" type="text" class="flex-1" />
        <NextButton
          :is-loading="isUpdatingEvolutionInstance"
          :disabled="isUpdatingEvolutionInstance"
          :label="t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
          @click="updateEvolutionInstance"
        />
      </div>
    </SettingsFieldSection>
    <SettingsToggleSection
      v-model="evolutionSignMessages"
      :header="t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_SIGN_MESSAGES')"
      :description="
        evolutionConfigurationError ||
        (isLoadingEvolutionConfiguration
          ? t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_CONFIGURATION_LOADING')
          : t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_SIGN_MESSAGES_HELP'))
      "
      :disabled="
        !evolutionSignMessagesAvailable ||
        isLoadingEvolutionConfiguration ||
        isUpdatingEvolutionSignMessages
      "
      @update:model-value="updateEvolutionSignMessages"
    >
      <template v-if="!evolutionInstanceName.trim()" #editor>
        <p class="text-label-small text-n-slate-11">
          {{ t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_SIGN_MESSAGES_DISABLED') }}
        </p>
      </template>
    </SettingsToggleSection>
  </SettingsAccordion>
</template>
