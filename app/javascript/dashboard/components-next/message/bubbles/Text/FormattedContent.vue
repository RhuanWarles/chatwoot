<script setup>
import { computed, inject, ref } from 'vue';
import { useMessageContext } from '../../provider.js';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { MESSAGE_VARIANTS } from '../../constants';
import {
  GROUP_MENTION_PARTICIPANTS,
  formatGroupMentionContent,
} from 'dashboard/helper/groupMentionRendering';
import { formatGroupSenderHeader } from 'dashboard/helper/messagePresentation';

const props = defineProps({
  content: {
    type: String,
    required: true,
  },
});

const {
  variant,
  contentAttributes,
  isPrivate,
  isGroupConversation,
  content: originalContent,
} = useMessageContext();
const participants = inject(GROUP_MENTION_PARTICIPANTS, ref(null));

const formattedContent = computed(() => {
  if (variant.value === MESSAGE_VARIANTS.ACTIVITY) {
    return props.content;
  }

  if (participants.value !== null && !isPrivate.value) {
    // MessageList converts message metadata to camelCase; the participants API
    // keeps snake_case. Convert only these identity fields for the resolver.
    const mentions =
      props.content === originalContent.value
        ? (contentAttributes.value.whatsappMentions || []).map(mention => ({
            lid: mention.lid,
            jid: mention.jid,
            phone: mention.phone,
            display_name: mention.displayName,
            start: mention.start,
            end: mention.end,
          }))
        : [];
    return formatGroupMentionContent(
      props.content,
      participants.value,
      mentions
    );
  }
    const formatted = new MessageFormatter(props.content).formattedMessage;
    return isGroupConversation.value
      ? formatGroupSenderHeader(formatted, props.content)
      : formatted;
});
</script>

<template>
  <span v-dompurify-html="formattedContent" class="prose prose-bubble" />
</template>
