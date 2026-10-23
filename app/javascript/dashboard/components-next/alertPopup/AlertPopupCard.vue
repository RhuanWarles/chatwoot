<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useTimeoutFn } from '@vueuse/core';
import { useMapGetter } from 'dashboard/composables/store';
import {
  ALERT_KIND,
  ALERT_POPUP_DURATION_MS,
  resolveAlertContact,
} from 'dashboard/helper/AudioAlerts/alertPopups';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MessagePreview from 'dashboard/components-next/Conversation/ConversationCard/MessagePreview.vue';
import UnreadBadge from 'dashboard/components-next/Conversation/ConversationCard/UnreadBadge.vue';

const props = defineProps({
  popup: { type: Object, required: true },
});

const emit = defineEmits(['open', 'close']);

const { t } = useI18n();
const getConversationById = useMapGetter('getConversationById');
const getInbox = useMapGetter('inboxes/getInbox');

const isHandoff = computed(() => props.popup.kind === ALERT_KIND.HANDOFF);
const conversation = computed(() =>
  getConversationById.value(props.popup.conversationId)
);
// The store fills the contact in later when the alert did not carry it (AI handoff note)
const contact = computed(() =>
  resolveAlertContact(props.popup, conversation.value)
);
const name = computed(
  () =>
    contact.value.name ||
    t('ALERT_POPUP.CONVERSATION_FALLBACK', { id: props.popup.conversationId })
);
const inbox = computed(() => {
  const record = getInbox.value(
    props.popup.inboxId ?? conversation.value?.inbox_id
  );
  return record.id ? record : null;
});
// One card per conversation: the badge counts the alerts merged into it
const badgeCount = computed(() =>
  props.popup.count > 1 ? props.popup.count : 0
);

const { start, stop } = useTimeoutFn(
  () => emit('close'),
  () => ALERT_POPUP_DURATION_MS[props.popup.kind]
);
// A merged alert restarts the countdown
watch(
  () => props.popup.revision,
  () => start()
);
</script>

<template>
  <div
    class="relative overflow-hidden border shadow-lg rounded-xl bg-n-solid-2"
    :class="isHandoff ? 'border-n-amber-4' : 'border-n-weak'"
    :role="isHandoff ? 'alert' : undefined"
    @mouseenter="stop"
    @mouseleave="start"
    @focusin="stop"
    @focusout="start"
  >
    <div
      role="button"
      tabindex="0"
      class="flex items-start w-full gap-3 p-3 cursor-pointer pe-10"
      :aria-label="t('ALERT_POPUP.OPEN_CONVERSATION', { name })"
      @click="emit('open')"
      @keydown.enter="emit('open')"
      @keydown.space.prevent="emit('open')"
    >
      <Avatar
        :name="name"
        :src="contact.thumbnail"
        :size="40"
        :inbox="inbox"
        rounded-full
      />
      <div class="flex flex-col flex-1 min-w-0 gap-0.5">
        <div class="flex items-center min-w-0 gap-2">
          <div class="truncate text-heading-3 text-n-slate-12">{{ name }}</div>
          <UnreadBadge :count="badgeCount" />
        </div>
        <div
          v-if="isHandoff"
          class="flex items-center gap-1 text-label-small text-n-amber-11"
        >
          <Icon icon="i-lucide-bot" class="size-3.5" />
          <span>{{ t('ALERT_POPUP.HANDOFF_TITLE') }}</span>
        </div>
        <div
          v-if="popup.summary"
          class="text-body-main text-n-slate-11 line-clamp-3"
        >
          {{ popup.summary }}
        </div>
        <MessagePreview
          v-else-if="popup.message"
          :message="popup.message"
          multi-line
          class="text-n-slate-11"
        />
        <div v-else class="text-body-main text-n-slate-11">
          {{ t('ALERT_POPUP.HANDOFF_WAITING') }}
        </div>
      </div>
    </div>
    <Button
      type="button"
      icon="i-lucide-x"
      slate
      ghost
      xs
      class="absolute top-2 end-2"
      :aria-label="t('ALERT_POPUP.CLOSE')"
      @click="emit('close')"
    />
  </div>
</template>
