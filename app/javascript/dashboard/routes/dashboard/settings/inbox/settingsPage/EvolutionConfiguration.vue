<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { useAccount } from 'dashboard/composables/useAccount';
import inboxesAPI from 'dashboard/api/inboxes';
import WhatsappConnectionsAPI from 'dashboard/api/whatsappConnections';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SettingsAccordion from 'dashboard/components-next/Settings/SettingsAccordion.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import ConnectionStatus from 'dashboard/routes/dashboard/whatsapp/ConnectionStatus.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const isAvailable = useMapGetter('globalConfig/isWhatsappConnectionsEnabled');
const { run, abort } = useAbortableRequest();
const evolutionInstanceName = ref('');
const connections = ref([]);
const selectedConnectionId = ref('');
const selectedConnection = computed(() =>
  connections.value.find(item => item.id === selectedConnectionId.value)
);
const currentConnection = computed(() =>
  connections.value.find(
    item => item.instance_name === evolutionInstanceName.value
  )
);
const connectionOptions = computed(() => [
  ...(evolutionInstanceName.value && !currentConnection.value
    ? [{ value: 'legacy', label: t('WHATSAPP_CONNECTIONS.LEGACY_CONNECTION') }]
    : []),
  ...connections.value
    .filter(item => !item.inbox_id || item.inbox_id === props.inbox.id)
    .map(item => ({ value: item.id, label: item.display_name })),
]);
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
  if (
    !isAvailable.value ||
    !evolutionInstanceName.value.trim() ||
    !props.inbox.id
  )
    return;

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
  if (!selectedConnection.value) return;

  isUpdatingEvolutionInstance.value = true;
  try {
    await WhatsappConnectionsAPI.update(selectedConnectionId.value, {
      inbox_id: props.inbox.id,
    });
    await store.dispatch('inboxes/get');
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
    await loadEvolutionConfiguration();
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE')
    );
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
  [() => props.inbox, isAvailable],
  async () => {
    abort();
    setDefaults();
    if (!isAvailable.value) return;
    try {
      const response = await run(signal =>
        WhatsappConnectionsAPI.get({ signal })
      );
      if (!response) return;
      connections.value = response.data.connections;
      selectedConnectionId.value =
        currentConnection.value?.id ||
        (evolutionInstanceName.value ? 'legacy' : '');
    } catch (error) {
      connections.value = [];
    }
    loadEvolutionConfiguration();
  },
  { deep: true, immediate: true }
);
</script>

<template>
  <div>
    <SettingsAccordion
      v-if="isAvailable"
      :title="t('WHATSAPP_CONNECTIONS.TITLE')"
      class="mt-6"
    >
      <SettingsFieldSection
        :label="t('WHATSAPP_CONNECTIONS.SELECT_CONNECTION')"
      >
        <div class="flex items-center gap-2">
          <Select
            v-model="selectedConnectionId"
            :options="connectionOptions"
            :placeholder="t('WHATSAPP_CONNECTIONS.SELECT_CONNECTION')"
            :aria-label="t('WHATSAPP_CONNECTIONS.SELECT_CONNECTION')"
          />
          <NextButton
            :is-loading="isUpdatingEvolutionInstance"
            :disabled="isUpdatingEvolutionInstance || !selectedConnection"
            :label="t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
            @click="updateEvolutionInstance"
          />
        </div>
        <div
          v-if="selectedConnection"
          class="mt-3 flex flex-wrap items-center gap-2"
        >
          <ConnectionStatus :status="selectedConnection.status" />
          <span
            v-if="selectedConnection.phone_number"
            class="text-label-small text-n-slate-11"
          >
            {{ selectedConnection.phone_number }}
          </span>
          <NextButton
            variant="link"
            :label="t('WHATSAPP_CONNECTIONS.MANAGE')"
            @click="
              router.push(
                accountScopedRoute('whatsapp_connection', {
                  connectionId: selectedConnection.id,
                })
              )
            "
          />
        </div>
        <p
          v-if="
            selectedConnection &&
            evolutionInstanceName &&
            evolutionInstanceName !== selectedConnection.instance_name
          "
          class="mt-2 text-label-small text-n-amber-11"
        >
          {{ t('WHATSAPP_CONNECTIONS.REPLACE_LEGACY') }}
        </p>
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
            {{
              t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION_SIGN_MESSAGES_DISABLED')
            }}
          </p>
        </template>
      </SettingsToggleSection>
    </SettingsAccordion>
  </div>
</template>
