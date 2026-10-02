<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import InboxesAPI from 'dashboard/api/inboxes';
import ContactAPI from 'dashboard/api/contacts';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';

const props = defineProps({ contactId: { type: Number, default: null } });
const { t, locale } = useI18n();
const conversations = ref([]);
const inboxes = ref([]);
const error = ref('');
const { run, abort, isPending: loading } = useAbortableRequest();
const date = value =>
  new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value * 1000));
watch(
  () => props.contactId,
  async id => {
    abort();
    conversations.value = [];
    error.value = '';
    if (!id) return;
    try {
      const result = await run(() =>
        Promise.all([ContactAPI.getConversations(id), InboxesAPI.get()])
      );
      if (result) {
        conversations.value = result[0].data.payload;
        inboxes.value = result[1].data.payload;
      }
    } catch {
      error.value = t('CRM.CONVERSATIONS_LOAD_ERROR');
    }
  },
  { immediate: true }
);
</script>

<template>
  <section class="flex flex-col gap-3 p-4 border border-n-weak rounded-xl">
    <h2 class="mb-0 text-base font-semibold text-n-slate-12">
      {{ t('CRM.MESSAGES') }}
    </h2>
    <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <p v-if="!contactId" class="mb-0 text-sm text-n-slate-11">
      {{ t('CRM.NO_CONTACT_CONVERSATIONS') }}
    </p>
    <p
      v-else-if="!loading && !error && !conversations.length"
      class="mb-0 text-sm text-n-slate-11"
    >
      {{ t('CRM.NO_CONVERSATIONS') }}
    </p>
    <RouterLink
      v-for="conversation in conversations"
      :key="conversation.id"
      :to="{
        name: 'inbox_conversation',
        params: {
          accountId: $route.params.accountId,
          conversation_id: conversation.id,
        },
      }"
      class="flex flex-wrap items-center justify-between gap-2 p-3 rounded-lg bg-n-alpha-2 hover:bg-n-alpha-3"
    >
      <div class="min-w-0">
        <p class="mb-1 text-sm font-medium text-n-slate-12">
          {{
            inboxes.find(inbox => inbox.id === conversation.inbox_id)?.name ||
            t('CRM.CONVERSATION')
          }}
          · #{{ conversation.id }}
        </p>
        <p class="mb-0 text-xs text-n-slate-11">
          {{
            t(`CRM.CONVERSATION_STATUS_${conversation.status.toUpperCase()}`)
          }}
          · {{ date(conversation.last_activity_at) }}
        </p>
      </div>
      <span class="text-sm text-n-brand">{{ t('CRM.OPEN_CONVERSATION') }}</span>
    </RouterLink>
  </section>
</template>
