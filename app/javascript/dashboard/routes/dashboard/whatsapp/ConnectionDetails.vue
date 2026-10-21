<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import WhatsappConnectionsAPI from 'dashboard/api/whatsappConnections';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import ConnectionStatus from './ConnectionStatus.vue';
import { useWhatsappConnection } from './useWhatsappConnection';

const props = defineProps({
  connectionId: { type: [String, Number], required: true },
  inboxes: { type: Array, default: () => [] },
  connections: { type: Array, default: () => [] },
});
const emit = defineEmits(['updated', 'deleted']);
const { t } = useI18n();
const { accountId } = useAccount();
const identity = computed(() => ({
  accountId: accountId.value,
  id: props.connectionId,
}));
const {
  connection,
  error,
  qrCode,
  qrExpired,
  providerUnavailable,
  isPending,
  apply,
  refresh,
  pause,
  resume,
  abort,
} = useWhatsappConnection(identity);
const busy = ref(false);
const displayName = ref('');
const inboxId = ref('');
const signMessages = ref(false);
const deleteDialog = ref(null);
const displayError = computed(() =>
  error.value === 'WHATSAPP_CONNECTIONS.REQUEST_ERROR'
    ? t('WHATSAPP_CONNECTIONS.REQUEST_ERROR')
    : error.value
);
const inboxOptions = computed(() => [
  { value: '', label: t('WHATSAPP_CONNECTIONS.NO_INBOX') },
  ...props.inboxes.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
    disabled: props.connections.some(
      item => item.inbox_id === inbox.id && item.id !== connection.value?.id
    ),
  })),
]);
const legacyReplacement = computed(() => {
  const inbox = props.inboxes.find(item => item.id === inboxId.value);
  return (
    inbox?.legacy_instance_name &&
    inbox.legacy_instance_name !== connection.value?.instance_name
  );
});

watch(
  () => connection.value?.id,
  () => {
    displayName.value = connection.value?.display_name || '';
    inboxId.value = connection.value?.inbox_id || '';
    signMessages.value = connection.value?.sign_msg === true;
  }
);

const perform = async (action, onSuccess) => {
  busy.value = true;
  error.value = '';
  pause();
  abort();
  const key = identity.value;
  try {
    const response = await action();
    if (key.accountId !== accountId.value || key.id !== props.connectionId)
      return;
    if (response.data?.id) apply(response.data);
    if (onSuccess) {
      onSuccess();
      return;
    }
    emit('updated');
    if (connection.value?.status === 'connecting') resume();
  } catch (exception) {
    if (key.accountId !== accountId.value || key.id !== props.connectionId)
      return;
    if (exception.response?.data?.connection)
      apply(exception.response.data.connection, { clearUnavailable: false });
    error.value =
      exception.response?.data?.message ||
      exception.response?.data?.error ||
      'WHATSAPP_CONNECTIONS.REQUEST_ERROR';
  } finally {
    busy.value = false;
  }
};

const save = () =>
  perform(() =>
    WhatsappConnectionsAPI.update(props.connectionId, {
      display_name: displayName.value.trim(),
      inbox_id: inboxId.value || null,
      sign_msg: signMessages.value,
    })
  );
const connect = () =>
  perform(() =>
    WhatsappConnectionsAPI.connect(
      props.connectionId,
      connection.value.status === 'connecting'
    )
  );
const disconnect = () =>
  perform(() => WhatsappConnectionsAPI.disconnect(props.connectionId));
const remove = async () => {
  await perform(
    () => WhatsappConnectionsAPI.delete(props.connectionId),
    () => {
      deleteDialog.value?.close();
      emit('deleted');
    }
  );
};
</script>

<template>
  <div
    class="flex flex-col gap-5 rounded-xl border border-n-weak bg-n-solid-1 p-6"
  >
    <p v-if="error" class="text-label-small text-n-ruby-11" role="alert">
      {{ displayError }}
    </p>
    <Spinner v-if="!connection && isPending" />
    <Button
      v-if="error"
      :label="t('WHATSAPP_CONNECTIONS.REFRESH')"
      variant="outline"
      :disabled="busy || isPending"
      @click="refresh"
    />
    <template v-if="connection">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 class="text-heading-2 text-n-slate-12">
          {{ connection.display_name }}
        </h2>
        <ConnectionStatus
          :status="providerUnavailable ? 'unavailable' : connection.status"
        />
      </div>
      <p v-if="connection.phone_number" class="text-body-main text-n-slate-11">
        {{ connection.phone_number }}
      </p>
      <p
        v-if="connection.profile_name"
        class="text-label-small text-n-slate-11"
      >
        {{ connection.profile_name }}
      </p>
      <img
        v-if="connection.profile_picture_url"
        :src="connection.profile_picture_url"
        :alt="t('WHATSAPP_CONNECTIONS.PROFILE_PICTURE')"
        class="size-12 rounded-full"
      />
      <Input
        v-model="displayName"
        :label="t('WHATSAPP_CONNECTIONS.NAME')"
        :disabled="busy"
      />
      <label class="flex flex-col gap-2 text-label-small text-n-slate-12">
        {{ t('WHATSAPP_CONNECTIONS.INBOX') }}
        <Select
          v-model="inboxId"
          :options="inboxOptions"
          :aria-label="t('WHATSAPP_CONNECTIONS.INBOX')"
          :disabled="busy"
        />
      </label>
      <p v-if="legacyReplacement" class="text-label-small text-n-amber-11">
        {{ t('WHATSAPP_CONNECTIONS.REPLACE_LEGACY') }}
      </p>
      <SettingsToggleSection
        v-model="signMessages"
        :header="t('WHATSAPP_CONNECTIONS.SIGN_MESSAGES')"
        :description="
          connection.inbox_id
            ? t('WHATSAPP_CONNECTIONS.SIGN_MESSAGES_HELP')
            : t('WHATSAPP_CONNECTIONS.SIGN_MESSAGES_DISABLED')
        "
        :disabled="busy || !connection.inbox_id"
      />
      <div class="flex flex-wrap gap-2">
        <Button
          :label="t('WHATSAPP_CONNECTIONS.SAVE')"
          :disabled="
            busy || !displayName.trim() || displayName.trim().length > 100
          "
          :is-loading="busy"
          @click="save"
        />
        <Button
          v-if="connection.status !== 'connected'"
          :label="
            t(
              connection.status === 'connecting'
                ? 'WHATSAPP_CONNECTIONS.REGENERATE_QR'
                : 'WHATSAPP_CONNECTIONS.CONNECT'
            )
          "
          variant="outline"
          :disabled="busy"
          @click="connect"
        />
        <Button
          v-if="['connected', 'connecting'].includes(connection.status)"
          :label="t('WHATSAPP_CONNECTIONS.DISCONNECT')"
          variant="outline"
          :disabled="busy"
          @click="disconnect"
        />
        <Button
          :label="t('WHATSAPP_CONNECTIONS.DELETE')"
          color="ruby"
          variant="faded"
          :disabled="busy"
          @click="deleteDialog.open()"
        />
      </div>
      <div
        v-if="connection.status === 'connecting'"
        class="flex flex-col items-center gap-3 rounded-lg bg-n-alpha-1 p-6"
        aria-live="polite"
      >
        <template v-if="qrExpired">
          <p class="text-heading-3 text-n-amber-11">
            {{ t('WHATSAPP_CONNECTIONS.QR_EXPIRED') }}
          </p>
          <Button
            :label="t('WHATSAPP_CONNECTIONS.REGENERATE_QR')"
            :disabled="busy"
            @click="connect"
          />
        </template>
        <template v-else>
          <p class="text-heading-3 text-n-slate-12">
            {{ t('WHATSAPP_CONNECTIONS.SCAN_QR') }}
          </p>
          <img
            v-if="qrCode"
            :src="qrCode"
            :alt="t('WHATSAPP_CONNECTIONS.QR_ALT')"
            class="size-64 rounded-lg bg-white p-3"
          />
          <Spinner v-else />
          <p class="text-label-small text-n-slate-11">
            {{ t('WHATSAPP_CONNECTIONS.WAITING') }}
          </p>
        </template>
      </div>
    </template>
    <Dialog
      ref="deleteDialog"
      type="alert"
      :title="t('WHATSAPP_CONNECTIONS.DELETE')"
      :description="t('WHATSAPP_CONNECTIONS.DELETE_CONFIRMATION')"
      :confirm-button-label="t('WHATSAPP_CONNECTIONS.DELETE')"
      :is-loading="busy"
      @confirm="remove"
    />
  </div>
</template>
