<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import Message from './Message.vue';
import CampaignMessage from './CampaignMessage.vue';
import { MESSAGE_TYPES } from './constants.js';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { useMapGetter } from 'dashboard/composables/store.js';
import MessageApi from 'dashboard/api/inbox/message.js';
import { provideGroupMentionParticipants } from 'dashboard/composables/useGroupMentionParticipants';
import { formatMessageDaySeparator } from 'dashboard/helper/messagePresentation';

/**
 * Props definition for the component
 * @typedef {Object} Props
 * @property {Array} readMessages - Array of read messages
 * @property {Array} unReadMessages - Array of unread messages
 * @property {Number} currentUserId - ID of the current user
 * @property {Boolean} isAnEmailChannel - Whether this is an email channel
 * @property {Object} inboxSupportsReplyTo - Inbox reply support configuration
 * @property {Array} messages - Array of all messages [These are not in camelcase]
 */
const props = defineProps({
  currentUserId: {
    type: Number,
    required: true,
  },
  firstUnreadId: {
    type: Number,
    default: null,
  },
  isAnEmailChannel: {
    type: Boolean,
    default: false,
  },
  inboxSupportsReplyTo: {
    type: Object,
    default: () => ({ incoming: false, outgoing: false }),
  },
  messages: {
    type: Array,
    default: () => [],
  },
  campaignHistory: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['retry']);
const { t, locale } = useI18n();

const allMessages = computed(() => {
  return useCamelCase(props.messages, {
    deep: true,
    stopPaths: [
      'content_attributes.translations',
      'content_attributes.whatsapp_flow_response.response_json',
    ],
  });
});

const currentChat = useMapGetter('getSelectedChat');
const contactGetter = useMapGetter('contacts/getContact');
const accountId = useMapGetter('getCurrentAccountId');
const groupContact = computed(() => ({
  identifier:
    contactGetter.value(currentChat.value.meta?.sender?.id).identifier ||
    currentChat.value.meta?.sender?.identifier,
}));
const isGroupConversation = computed(() => {
  const identifiers = [
    currentChat.value?.meta?.sender?.identifier,
    currentChat.value?.contact?.identifier,
    currentChat.value?.contactInbox?.sourceId,
    currentChat.value?.contact_inbox?.source_id,
  ];

  return identifiers.some(
    identifier =>
      typeof identifier === 'string' && identifier.endsWith('@g.us')
  );
});
provideGroupMentionParticipants(currentChat, groupContact, accountId);

const timeline = computed(() => {
  const messages = allMessages.value.map(message => ({
    key: `message-${message.id}`,
    createdAt: message.createdAt,
    message,
  }));
  const entries = props.campaignHistory.length
    ? [
    ...messages,
    ...props.campaignHistory.map(recipient => ({
      key: `campaign-${recipient.id}`,
      createdAt: recipient.sent_at,
      recipient,
    })),
      ].sort((a, b) => a.createdAt - b.createdAt)
    : messages;

  let lastDayKey = null;
  let lastDayValue = null;
  return entries.reduce((result, entry) => {
    const separator = formatMessageDaySeparator(entry.createdAt, locale.value);
    if (separator.key !== lastDayKey || separator.value !== lastDayValue) {
      result.push({
        key: `day-${separator.key}-${separator.value || entry.createdAt}`,
        dayKey: separator.key,
        dayValue: separator.value,
        isDaySeparator: true,
      });
      lastDayKey = separator.key;
      lastDayValue = separator.value;
    }
    result.push(entry);
    return result;
  }, []);
});

const daySeparatorLabel = entry => {
  if (entry.dayKey === 'today') return t('CONVERSATION.DATE_SEPARATOR.TODAY');
  if (entry.dayKey === 'yesterday') {
    return t('CONVERSATION.DATE_SEPARATOR.YESTERDAY');
  }
  return entry.dayValue;
};

// Cache for fetched reply messages to avoid duplicate API calls
const fetchedReplyMessages = reactive(new Map());

/**
 * Fetches a specific message from the API by trying to get messages around it
 * @param {number} messageId - The ID of the message to fetch
 * @param {number} conversationId - The ID of the conversation
 * @returns {Promise<Object|null>} - The fetched message or null if not found/error
 */
const fetchReplyMessage = async (messageId, conversationId) => {
  // Return cached result if already fetched
  if (fetchedReplyMessages.has(messageId)) {
    return fetchedReplyMessages.get(messageId);
  }

  try {
    const response = await MessageApi.getPreviousMessages({
      conversationId,
      before: messageId + 100,
      after: messageId - 100,
    });

    const messages = response.data?.payload || [];
    const targetMessage = messages.find(msg => msg.id === messageId);

    if (targetMessage) {
      const camelCaseMessage = useCamelCase(targetMessage);
      fetchedReplyMessages.set(messageId, camelCaseMessage);
      return camelCaseMessage;
    }

    // Cache null result to avoid repeated API calls
    fetchedReplyMessages.set(messageId, null);
    return null;
  } catch (error) {
    fetchedReplyMessages.set(messageId, null);
    return null;
  }
};

/**
 * Determines if a message should be grouped with the next message
 * @param {Object} current - Current message
 * @param {Object} next - Next message, absent at a campaign entry or the end
 * @returns {Boolean} - Whether the message should be grouped with next
 */
const shouldGroupWithNext = (current, next) => {
  if (!next || next.status === 'failed') return false;

  const nextSenderId = next.senderId ?? next.sender?.id;
  const currentSenderId = current.senderId ?? current.sender?.id;
  const hasSameSender = nextSenderId === currentSenderId;

  const nextMessageType = next.messageType;
  const currentMessageType = current.messageType;

  const areBothTemplates =
    nextMessageType === MESSAGE_TYPES.TEMPLATE &&
    currentMessageType === MESSAGE_TYPES.TEMPLATE;

  if (!hasSameSender || areBothTemplates) return false;

  if (currentMessageType !== nextMessageType) return false;

  // Check if messages are in the same minute by rounding down to nearest minute
  return Math.floor(next.createdAt / 60) === Math.floor(current.createdAt / 60);
};

/**
 * Gets the message that was replied to
 * @param {Object} parentMessage - The message containing the reply reference
 * @returns {Object|null} - The message being replied to, or null if not found
 */
const getInReplyToMessage = parentMessage => {
  if (!parentMessage) return null;

  const inReplyToMessageId =
    parentMessage.contentAttributes?.inReplyTo ??
    parentMessage.content_attributes?.in_reply_to;

  if (!inReplyToMessageId) return null;

  // Try to find in current messages first
  let replyMessage = props.messages?.find(msg => msg.id === inReplyToMessageId);

  // Then try store messages
  if (!replyMessage && currentChat.value?.messages) {
    replyMessage = currentChat.value.messages.find(
      msg => msg.id === inReplyToMessageId
    );
  }

  // Then check fetch cache
  if (!replyMessage && fetchedReplyMessages.has(inReplyToMessageId)) {
    replyMessage = fetchedReplyMessages.get(inReplyToMessageId);
  }

  // If still not found and we have conversation context, fetch it
  if (!replyMessage && currentChat.value?.id) {
    fetchReplyMessage(inReplyToMessageId, currentChat.value.id);
    return null; // Let UI handle loading state
  }

  return replyMessage ? useCamelCase(replyMessage) : null;
};
</script>

<template>
  <ul class="px-4 bg-n-surface-1">
    <slot name="beforeAll" />
    <template v-for="(entry, index) in timeline" :key="entry.key">
      <slot
        v-if="firstUnreadId && entry.message?.id === firstUnreadId"
        name="unreadBadge"
      />
      <li
        v-if="entry.isDaySeparator"
        class="flex justify-center py-3"
        data-message-day-separator
        :data-day-key="entry.dayKey"
        :data-day-value="entry.dayValue"
        :aria-label="daySeparatorLabel(entry)"
      >
        <span class="px-3 py-1 text-xs rounded-full bg-n-alpha-2 text-n-slate-11">
          {{ daySeparatorLabel(entry) }}
        </span>
      </li>
      <template v-if="!entry.isDaySeparator">
        <CampaignMessage v-if="entry.recipient" :recipient="entry.recipient" />
        <Message
          v-else
          v-bind="entry.message"
          :is-email-inbox="isAnEmailChannel"
          :in-reply-to="getInReplyToMessage(entry.message)"
          :group-with-next="
            shouldGroupWithNext(entry.message, timeline[index + 1]?.message)
          "
          :inbox-supports-reply-to="inboxSupportsReplyTo"
          :current-user-id="currentUserId"
          :is-group-conversation="isGroupConversation"
          data-clarity-mask="True"
          @retry="emit('retry', entry.message)"
        />
      </template>
    </template>
    <slot name="after" />
  </ul>
</template>
