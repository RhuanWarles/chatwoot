<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import AudioChip from 'next/message/chips/Audio.vue';
import { useMessageContext } from '../provider.js';
import { MESSAGE_TYPES } from '../constants';

const { attachments, conversationId, messageType } = useMessageContext();

// Only audios received from the customer can be transcribed by hand.
const transcribeIn = computed(() =>
  messageType.value === MESSAGE_TYPES.INCOMING ? conversationId.value : null
);

const attachment = computed(() => {
  return attachments.value[0];
});
</script>

<template>
  <BaseBubble class="bg-transparent" data-bubble-name="audio">
    <AudioChip
      :attachment="attachment"
      :conversation-id="transcribeIn"
      class="p-2 text-n-slate-12 skip-context-menu"
    />
  </BaseBubble>
</template>
