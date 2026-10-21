import { computed, onScopeDispose, ref, watch } from 'vue';
import { useIntervalFn, useNow } from '@vueuse/core';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import WhatsappConnectionsAPI from 'dashboard/api/whatsappConnections';

export const POLLING_INTERVAL = 3000;
export const QR_DISPLAY_TIMEOUT = 60000;

export function useWhatsappConnection(identity) {
  const connection = ref(null);
  const error = ref('');
  const providerUnavailable = ref(false);
  const qrCode = ref(null);
  const qrUpdatedAt = ref(0);
  let polling;
  const { run, abort, isPending } = useAbortableRequest();
  const now = useNow({ interval: 1000 });
  const qrExpired = computed(
    () =>
      qrUpdatedAt.value > 0 &&
      now.value.getTime() - qrUpdatedAt.value >= QR_DISPLAY_TIMEOUT
  );

  const apply = (data, { clearUnavailable = true } = {}) => {
    connection.value = data;
    if (clearUnavailable) providerUnavailable.value = false;
    if (data.status === 'connecting' && !qrUpdatedAt.value)
      qrUpdatedAt.value = Date.now();
    if (data.qr_code && data.qr_code !== qrCode.value) {
      qrUpdatedAt.value = Date.now();
      qrCode.value = data.qr_code;
    }
    if (data.status === 'connected' || data.status === 'disconnected') {
      qrCode.value = null;
      qrUpdatedAt.value = 0;
    }
  };

  const refresh = async () => {
    if (!identity.value.id || isPending.value) return;
    const key = `${identity.value.accountId}:${identity.value.id}`;
    error.value = '';
    try {
      const response = await run(signal =>
        WhatsappConnectionsAPI.show(identity.value.id, { signal })
      );
      if (
        !response ||
        key !== `${identity.value.accountId}:${identity.value.id}`
      )
        return;
      apply(response.data);
      if (connection.value.status === 'connecting') polling.resume();
      else polling.pause();
    } catch (exception) {
      providerUnavailable.value = true;
      error.value =
        exception.response?.data?.message ||
        exception.response?.data?.error ||
        'WHATSAPP_CONNECTIONS.REQUEST_ERROR';
      if (exception.response?.data?.connection)
        apply(exception.response.data.connection, { clearUnavailable: false });
      polling.pause();
    }
  };

  polling = useIntervalFn(refresh, POLLING_INTERVAL, {
    immediate: false,
  });

  watch(
    identity,
    () => {
      polling.pause();
      abort();
      connection.value = null;
      qrCode.value = null;
      qrUpdatedAt.value = 0;
      providerUnavailable.value = false;
      refresh();
    },
    { immediate: true }
  );

  onScopeDispose(polling.pause);

  return {
    connection,
    error,
    qrCode,
    qrExpired,
    providerUnavailable,
    isPending,
    apply,
    refresh,
    pause: polling.pause,
    resume: polling.resume,
    abort,
  };
}
