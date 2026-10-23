<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useEmitter } from 'dashboard/composables/emitter';
import { useMapGetter } from 'dashboard/composables/store';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { useCallsStore } from 'dashboard/stores/calls';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import {
  ALERT_KIND,
  dismissAlertPopup,
  resolveAlertContact,
  upsertAlertPopup,
} from 'dashboard/helper/AudioAlerts/alertPopups';
import {
  getDesktopPermission,
  showDesktopNotification,
} from 'dashboard/helper/AudioAlerts/desktopNotification';
import AlertPopupCard from './AlertPopupCard.vue';

const { t } = useI18n();
const router = useRouter();
const { getPlainText } = useMessageFormatter();
const callsStore = useCallsStore();
const accountId = useMapGetter('getCurrentAccountId');
const selectedChat = useMapGetter('getSelectedChat');
const getConversationById = useMapGetter('getConversationById');

const popups = ref([]);

// The call widget uses the same corner; keep its accept/reject buttons clickable
const hasCall = computed(
  () => callsStore.hasActiveCall || callsStore.hasIncomingCall
);

const closePopup = alert => {
  popups.value = dismissAlertPopup(popups.value, alert.key);
};

const openConversation = alert => {
  closePopup(alert);
  if (!alert.conversationId) return;
  router.push({
    path: frontendURL(
      conversationUrl({
        accountId: accountId.value,
        id: alert.conversationId,
      })
    ),
  });
};

const previewText = ({
  content,
  content_attributes: contentAttributes,
  attachments,
}) => {
  const text = contentAttributes?.email?.subject || content;
  if (text) return getPlainText(text);
  const [attachment] = attachments || [];
  return attachment
    ? t(`CHAT_LIST.ATTACHMENTS.${attachment.file_type}.CONTENT`)
    : t('CHAT_LIST.NO_CONTENT');
};

const showDesktopAlert = ({ alert, silent }) => {
  if (getDesktopPermission() !== 'granted') return;

  const isHandoff = alert.kind === ALERT_KIND.HANDOFF;
  const contact = resolveAlertContact(
    alert,
    getConversationById.value(alert.conversationId)
  );
  const handoffBody = `${t('ALERT_POPUP.HANDOFF_TITLE')}: ${alert.summary || t('ALERT_POPUP.HANDOFF_WAITING')}`;

  showDesktopNotification({
    title:
      contact.name ||
      t('ALERT_POPUP.CONVERSATION_FALLBACK', { id: alert.conversationId }),
    body: isHandoff ? handoffBody : previewText(alert.message),
    icon: contact.thumbnail,
    tag: `conversation-${alert.key}`,
    silent,
    requireInteraction: isHandoff,
    onClick: () => openConversation(alert),
  });
};

useEmitter(BUS_EVENTS.SHOW_ALERT_POPUP, alert => {
  popups.value = upsertAlertPopup(popups.value, alert);
});
useEmitter(BUS_EVENTS.SHOW_DESKTOP_ALERT, showDesktopAlert);

// Opening the conversation by any route clears its card, like a chat app
watch(
  () => selectedChat.value.id,
  id => {
    if (id) popups.value = dismissAlertPopup(popups.value, String(id));
  }
);
</script>

<template>
  <div
    class="fixed z-50 flex flex-col gap-2 bottom-20 end-4 w-80 max-w-[calc(100vw-2rem)]"
    :class="{ 'md:end-[27rem]': hasCall }"
    role="region"
    aria-live="polite"
    :aria-label="t('ALERT_POPUP.REGION_LABEL')"
  >
    <TransitionGroup
      enter-active-class="animate-fade-in-up motion-reduce:animate-none"
      leave-active-class="transition duration-200 ease-in motion-reduce:transition-none"
      leave-to-class="opacity-0 translate-y-2"
    >
      <AlertPopupCard
        v-for="popup in popups"
        :key="popup.key"
        :popup="popup"
        @open="openConversation(popup)"
        @close="closePopup(popup)"
      />
    </TransitionGroup>
  </div>
</template>
