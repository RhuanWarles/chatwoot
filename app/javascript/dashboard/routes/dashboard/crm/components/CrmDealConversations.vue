<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import InboxesAPI from 'dashboard/api/inboxes';
import ContactAPI from 'dashboard/api/contacts';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';

const props = defineProps({ contactId: { type: Number, default: null } });
const { t, locale } = useI18n();
const conversations = ref([]);
const inboxes = ref([]);
const error = ref('');
const sortedConversations = computed(() =>
  [...conversations.value].sort(
    (a, b) => b.last_activity_at - a.last_activity_at
  )
);
const inboxFor = conversation =>
  inboxes.value.find(item => item.id === conversation.inbox_id);
const channelFor = conversation => {
  const inbox = inboxFor(conversation);
  const type = inbox?.channel_type || conversation.meta?.channel;
  if (type === 'Channel::TwilioSms')
    return inbox?.medium === 'whatsapp' ? 'WHATSAPP' : 'SMS';
  return type?.replace('Channel::', '').toUpperCase() || 'API';
};
const lastMessage = conversation => conversation.last_non_activity_message;

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
      if (result && props.contactId === id) {
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
    <p v-if="loading" role="status" class="mb-0 text-sm text-n-slate-11">
      {{ t('CRM.CONVERSATIONS_LOADING') }}
    </p>
    <RouterLink
      v-for="conversation in sortedConversations"
      :key="conversation.id"
      :to="{
        name: 'inbox_conversation',
        params: {
          accountId: $route.params.accountId,
          conversation_id: conversation.id,
        },
      }"
      class="flex flex-col min-w-0 gap-1.5 p-3 rounded-lg border hover:bg-n-alpha-3 focus-visible:ring-2 focus-visible:ring-n-brand"
      :class="
        conversation.status === 'open'
          ? 'border-n-brand/30 bg-n-blue-2'
          : 'border-n-weak bg-n-alpha-2'
      "
    >
      <div class="flex items-center gap-2 min-w-0">
        <span
          class="flex-shrink-0 text-n-slate-11"
          :class="
            getInboxIconByType(
              inboxFor(conversation)?.channel_type ||
                conversation.meta?.channel,
              inboxFor(conversation)?.medium
            )
          "
        />
        <p
          class="flex-1 min-w-0 mb-0 text-sm font-medium text-n-slate-12 truncate"
        >
          {{ t(`CRM.CHANNEL_${channelFor(conversation)}`) }}
          <span v-if="inboxFor(conversation)?.name">
            · {{ inboxFor(conversation).name }}</span
          >
        </p>
        <span
          class="text-xs flex-shrink-0"
          :class="
            conversation.status === 'open'
              ? 'text-n-teal-11'
              : 'text-n-slate-11'
          "
        >
          {{
            t(`CRM.CONVERSATION_STATUS_${conversation.status.toUpperCase()}`)
          }}
        </span>
        <span
          v-if="conversation.unread_count"
          class="rounded-full px-1.5 text-xs bg-n-blue-3 text-n-blue-11"
          :title="
            t('CRM.CONVERSATIONS_UNREAD', { count: conversation.unread_count })
          "
        >
          {{ conversation.unread_count }}
        </span>
      </div>
      <p
        v-if="lastMessage(conversation)?.content"
        class="mb-0 text-sm text-n-slate-11 line-clamp-2 [overflow-wrap:anywhere]"
      >
        {{ lastMessage(conversation).content }}
      </p>
      <p
        v-else-if="lastMessage(conversation)?.attachments?.length"
        class="mb-0 text-sm text-n-slate-11"
      >
        {{ t('CRM.CONVERSATIONS_ATTACHMENT') }}
      </p>
      <div class="flex flex-wrap items-center justify-between gap-2">
        <p class="mb-0 text-xs text-n-slate-10">
          {{
            date(
              lastMessage(conversation)?.created_at ||
                conversation.last_activity_at
            )
          }}
          <span v-if="conversation.meta?.assignee?.name">
            · {{ t('CRM.OWNER') }}: {{ conversation.meta.assignee.name }}</span
          >
        </p>
        <span class="text-xs text-n-brand">{{
          t('CRM.OPEN_CONVERSATION')
        }}</span>
      </div>
    </RouterLink>
  </section>
</template>
