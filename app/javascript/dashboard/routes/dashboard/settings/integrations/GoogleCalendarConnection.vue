<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import CalendarAPI from 'dashboard/api/crmCalendar';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
const { t } = useI18n();
const route = useRoute();
const connection = ref(null);
const error = ref('');
const saving = ref(false);
const { run, isPending: loading } = useAbortableRequest();
const RESULTS = {
  connected: 'CRM.CALENDAR_CONNECTED_SUCCESS',
  cancelled: 'CRM.CALENDAR_OAUTH_CANCELLED',
  failed: 'CRM.CALENDAR_OAUTH_FAILED',
};
const resultMessage = computed(() =>
  RESULTS[route.query.result] ? t(RESULTS[route.query.result]) : ''
);
const load = async () => {
  connection.value = null;
  error.value = '';
  try {
    const result = await run(signal => CalendarAPI.get({ signal }));
    if (result) connection.value = result.data;
  } catch {
    error.value = t('CRM.CALENDAR_LOAD_ERROR');
  }
};
const connect = async () => {
  saving.value = true;
  error.value = '';
  try {
    window.location.assign((await CalendarAPI.create({})).data.url);
  } catch {
    error.value = t('CRM.CALENDAR_OAUTH_FAILED');
    saving.value = false;
  }
};
const disconnect = async () => {
  saving.value = true;
  error.value = '';
  try {
    const result = await CalendarAPI.disconnect();
    await load();
    if (result.data.revocation_failed)
      error.value = t('CRM.CALENDAR_REVOCATION_FAILED');
  } catch {
    error.value = t('CRM.CALENDAR_DISCONNECT_ERROR');
  } finally {
    saving.value = false;
  }
};
watch(() => route.params.accountId, load, { immediate: true });
</script>

<template>
  <section
    class="flex flex-col gap-3 p-5 rounded-xl border border-n-weak bg-n-alpha-2"
  >
    <h2 class="mb-0 text-base font-semibold text-n-slate-12">
      {{ t('CRM.CALENDAR_TITLE') }}
    </h2>
    <p class="mb-0 text-sm text-n-slate-11">
      {{ t('CRM.CALENDAR_PERSONAL_CONNECTION') }}
    </p>
    <p v-if="resultMessage" role="status" class="mb-0 text-sm text-n-slate-12">
      {{ resultMessage }}
    </p>
    <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <template v-if="connection">
      <p class="mb-0 text-sm font-medium text-n-slate-12">
        {{
          t(
            connection.connected
              ? 'CRM.CALENDAR_CONNECTED'
              : 'CRM.CALENDAR_DISCONNECTED'
          )
        }}<span v-if="connection.email"> · {{ connection.email }}</span>
      </p>
      <p v-if="!connection.configured" class="mb-0 text-sm text-n-amber-11">
        {{ t('CRM.CALENDAR_SETUP_REQUIRED') }}
      </p>
      <Button
        v-if="connection.connected"
        :label="t('CRM.CALENDAR_RECONNECT')"
        :disabled="!connection.configured"
        :is-loading="saving"
        variant="faded"
        @click="connect"
      />
      <Button
        v-if="connection.connected"
        :label="t('CRM.CALENDAR_DISCONNECT')"
        variant="faded"
        :is-loading="saving"
        @click="disconnect"
      />
      <Button
        v-else
        :label="t('CRM.CALENDAR_CONNECT')"
        :disabled="!connection.configured || loading"
        :is-loading="saving"
        @click="connect"
      />
      <p v-if="!connection.connected" class="mb-0 text-xs text-n-slate-11">
        {{ t('CRM.CALENDAR_DISCONNECTED_HINT') }}
      </p>
    </template>
  </section>
</template>
