<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import WhatsappConnectionsAPI from 'dashboard/api/whatsappConnections';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ConnectionStatus from './ConnectionStatus.vue';
import ConnectionDetails from './ConnectionDetails.vue';

const { t } = useI18n();
const { accountId, route, accountScopedRoute } = useAccount();
const router = useRouter();
const { run, isPending } = useAbortableRequest();
const connections = ref([]);
const inboxes = ref([]);
const error = ref('');
const createDialog = ref(null);
const displayName = ref('');
const inboxId = ref('');
const isCreating = ref(false);
const inboxOptions = computed(() => [
  { value: '', label: t('WHATSAPP_CONNECTIONS.NO_INBOX') },
  ...inboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
    disabled: connections.value.some(item => item.inbox_id === inbox.id),
  })),
]);
const legacyReplacement = computed(
  () =>
    inboxes.value.find(item => item.id === inboxId.value)?.legacy_instance_name
);

const load = async () => {
  const currentAccountId = accountId.value;
  try {
    const response = await run(signal =>
      WhatsappConnectionsAPI.get({ signal })
    );
    if (!response || currentAccountId !== accountId.value) return;
    connections.value = response.data.connections;
    inboxes.value = response.data.inboxes;
    error.value = '';
  } catch (exception) {
    error.value =
      exception.response?.data?.error || 'WHATSAPP_CONNECTIONS.REQUEST_ERROR';
  }
};
const manage = id =>
  router.push(accountScopedRoute('whatsapp_connection', { connectionId: id }));
const back = () => router.push(accountScopedRoute('whatsapp_connections'));
const create = async () => {
  isCreating.value = true;
  error.value = '';
  const currentAccountId = accountId.value;
  try {
    const response = await WhatsappConnectionsAPI.create({
      display_name: displayName.value.trim(),
      inbox_id: inboxId.value || null,
    });
    if (currentAccountId !== accountId.value) return;
    createDialog.value.close();
    await load();
    manage(response.data.id);
  } catch (exception) {
    if (currentAccountId !== accountId.value) return;
    error.value =
      exception.response?.data?.error || 'WHATSAPP_CONNECTIONS.REQUEST_ERROR';
    if (exception.response?.data?.connection?.id) {
      createDialog.value.close();
      await load();
      manage(exception.response.data.connection.id);
    }
  } finally {
    isCreating.value = false;
  }
};
const openCreate = () => {
  displayName.value = '';
  inboxId.value = '';
  createDialog.value.open();
};
const deleted = async () => {
  await back();
  load();
};
watch(
  accountId,
  () => {
    connections.value = [];
    inboxes.value = [];
    createDialog.value?.close();
    load();
  },
  { immediate: true }
);
</script>

<template>
  <section
    class="flex h-full w-full flex-col overflow-auto bg-n-background px-6 py-8"
  >
    <div class="mx-auto flex w-full max-w-5xl flex-col gap-6">
      <header class="flex flex-wrap items-center justify-between gap-3">
        <h1 class="text-heading-1 text-n-slate-12">
          {{ t('WHATSAPP_CONNECTIONS.TITLE') }}
        </h1>
        <Button
          v-if="!route.params.connectionId"
          icon="i-lucide-plus"
          :label="t('WHATSAPP_CONNECTIONS.NEW')"
          @click="openCreate"
        />
        <Button
          v-else
          :label="t('WHATSAPP_CONNECTIONS.BACK')"
          variant="outline"
          @click="back"
        />
      </header>
      <p v-if="error" class="text-label-small text-n-ruby-11" role="alert">
        {{ t(error) }}
      </p>
      <Button
        v-if="error"
        :label="t('WHATSAPP_CONNECTIONS.REFRESH')"
        variant="outline"
        @click="load"
      />
      <ConnectionDetails
        v-if="route.params.connectionId"
        :key="`${accountId}:${route.params.connectionId}`"
        :connection-id="route.params.connectionId"
        :connections="connections"
        :inboxes="inboxes"
        @updated="load"
        @deleted="deleted"
      />
      <Spinner v-else-if="isPending" />
      <template v-else>
        <div
          v-if="!connections.length"
          class="flex flex-col items-center gap-3 rounded-xl border border-dashed border-n-weak p-10 text-center"
        >
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('WHATSAPP_CONNECTIONS.EMPTY_TITLE') }}
          </h2>
          <p class="text-body-main text-n-slate-11">
            {{ t('WHATSAPP_CONNECTIONS.EMPTY_DESCRIPTION') }}
          </p>
          <Button :label="t('WHATSAPP_CONNECTIONS.NEW')" @click="openCreate" />
        </div>
        <div v-else class="grid grid-cols-1 gap-4 md:grid-cols-2">
          <article
            v-for="connection in connections"
            :key="connection.id"
            class="flex flex-col gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-5"
          >
            <div class="flex items-center justify-between gap-2">
              <h2 class="text-heading-2 text-n-slate-12">
                {{ connection.display_name }}
              </h2>
              <ConnectionStatus :status="connection.status" />
            </div>
            <p
              v-if="connection.phone_number"
              class="text-body-main text-n-slate-11"
            >
              {{ connection.phone_number }}
            </p>
            <p class="text-label-small text-n-slate-11">
              {{
                t('WHATSAPP_CONNECTIONS.INBOX_LABEL', {
                  name:
                    connection.inbox?.name ||
                    t('WHATSAPP_CONNECTIONS.NO_INBOX'),
                })
              }}
            </p>
            <Button
              :label="t('WHATSAPP_CONNECTIONS.MANAGE')"
              variant="outline"
              @click="manage(connection.id)"
            />
          </article>
        </div>
      </template>
    </div>
    <Dialog
      ref="createDialog"
      :title="t('WHATSAPP_CONNECTIONS.NEW')"
      :confirm-button-label="t('WHATSAPP_CONNECTIONS.CREATE')"
      :is-loading="isCreating"
      :disable-confirm-button="
        !displayName.trim() || displayName.trim().length > 100
      "
      @confirm="create"
    >
      <Input
        v-model="displayName"
        :label="t('WHATSAPP_CONNECTIONS.NAME')"
        :disabled="isCreating"
      />
      <label class="flex flex-col gap-2 text-label-small text-n-slate-12">
        {{ t('WHATSAPP_CONNECTIONS.INBOX') }}
        <Select
          v-model="inboxId"
          :options="inboxOptions"
          :aria-label="t('WHATSAPP_CONNECTIONS.INBOX')"
          :disabled="isCreating"
        />
      </label>
      <p v-if="legacyReplacement" class="text-label-small text-n-amber-11">
        {{ t('WHATSAPP_CONNECTIONS.REPLACE_LEGACY') }}
      </p>
      <p v-if="error" class="text-label-small text-n-ruby-11" role="alert">
        {{ t(error) }}
      </p>
    </Dialog>
  </section>
</template>
