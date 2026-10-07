import { provide, ref, watch } from 'vue';
import groupParticipantsAPI from 'dashboard/api/conversations/groupParticipantsAPI';
import { GROUP_MENTION_PARTICIPANTS } from 'dashboard/helper/groupMentionRendering';

export const provideGroupMentionParticipants = (
  conversation,
  contact,
  accountId
) => {
  const participants = ref(null);
  provide(GROUP_MENTION_PARTICIPANTS, participants);

  watch(
    [
      () => accountId.value,
      () => conversation.value.id,
      () => contact.value?.identifier,
    ],
    async ([, conversationId, identifier], previous, onCleanup) => {
      participants.value = null;
      if (!conversationId || !identifier?.endsWith('@g.us')) return;

      participants.value = [];
      let active = true;
      onCleanup(() => {
        active = false;
      });
      try {
        const { data } = await groupParticipantsAPI(conversationId).get();
        if (active) participants.value = data.participants;
      } catch {
        // Keep the original text when participants are unavailable.
        if (active) participants.value = [];
      }
    },
    { immediate: true }
  );
};
