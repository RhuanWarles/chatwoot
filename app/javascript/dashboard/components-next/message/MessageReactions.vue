<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { useAlert } from 'dashboard/composables';
import messageReactionsAPI from 'dashboard/api/conversations/messageReactionsAPI';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  messageId: { type: Number, required: true },
  conversationId: { type: Number, required: true },
  currentUserId: { type: Number, required: true },
  reactions: { type: Array, default: () => [] },
});
const EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🙏', '✅'];
const { t } = useI18n();
const picker = ref(null);
const participantsDialog = ref(null);
const selectedEmoji = ref('');
const localReactions = ref([]);
const busy = ref(false);
watch(
  () => props.reactions,
  records => {
    localReactions.value = useCamelCase(records, { deep: true });
  },
  { immediate: true }
);
const active = computed(() =>
  localReactions.value.filter(reaction => reaction.emoji)
);
const own = computed(() => active.value.find(reaction => reaction.fromMe));
const canRemove = computed(
  () =>
    !!own.value &&
    (!own.value.userId || own.value.userId === props.currentUserId)
);
const groups = computed(() =>
  [...new Set(active.value.map(reaction => reaction.emoji))].map(emoji => ({
    emoji,
    count: active.value.filter(reaction => reaction.emoji === emoji).length,
  }))
);
const selectedParticipants = computed(() =>
  active.value.filter(reaction => reaction.emoji === selectedEmoji.value)
);
const openPicker = () => picker.value.open();
const showParticipants = emoji => {
  selectedEmoji.value = emoji;
  participantsDialog.value.open();
};
const send = async emoji => {
  if (busy.value) return;
  busy.value = true;
  picker.value.close();
  const previous = localReactions.value;
  const next = localReactions.value.filter(reaction => !reaction.fromMe);
  if (emoji)
    next.push({
      participantKey: 'self',
      fromMe: true,
      userId: props.currentUserId,
      displayName: t('MESSAGE_REACTIONS.YOU'),
      emoji,
    });
  localReactions.value = next;
  try {
    const { data } = await messageReactionsAPI.react(
      props.conversationId,
      props.messageId,
      emoji
    );
    localReactions.value = useCamelCase(data.reactions, { deep: true });
  } catch {
    localReactions.value = [
      ...localReactions.value.filter(reaction => !reaction.fromMe),
      ...previous.filter(reaction => reaction.fromMe),
    ];
    useAlert(t('MESSAGE_REACTIONS.ERROR'));
  } finally {
    busy.value = false;
  }
};
const choose = emoji =>
  send(canRemove.value && own.value?.emoji === emoji ? '' : emoji);
defineExpose({ openPicker });
</script>

<template>
  <div class="flex flex-wrap items-center gap-1">
    <button
      v-for="group in groups"
      :key="group.emoji"
      type="button"
      class="flex items-center gap-1 rounded-full border border-n-weak bg-n-solid-2 px-2 py-0.5 text-xs text-n-slate-12"
      :aria-label="
        t('MESSAGE_REACTIONS.COUNT', { emoji: group.emoji, count: group.count })
      "
      @click="showParticipants(group.emoji)"
    >
      <span>{{ group.emoji }}</span>
      <span>{{ group.count }}</span>
    </button>
    <Button
      icon="i-lucide-smile-plus"
      size="xs"
      variant="ghost"
      color="slate"
      class="md:opacity-0 group-hover:opacity-100 group-focus-within:opacity-100"
      :aria-label="t('MESSAGE_REACTIONS.ADD')"
      :disabled="busy"
      @click="openPicker"
    />
    <Dialog
      ref="picker"
      width="sm"
      :title="t('MESSAGE_REACTIONS.ADD')"
      :show-confirm-button="false"
      :show-cancel-button="false"
    >
      <div class="flex flex-wrap gap-2">
        <button
          v-for="emoji in EMOJIS"
          :key="emoji"
          type="button"
          class="rounded-lg p-2 text-2xl hover:bg-n-solid-2"
          :aria-label="emoji"
          :disabled="busy"
          @click="choose(emoji)"
        >
          {{ emoji }}
        </button>
      </div>
      <Button
        v-if="canRemove"
        class="mt-3"
        variant="ghost"
        :label="t('MESSAGE_REACTIONS.REMOVE')"
        @click="send('')"
      />
    </Dialog>
    <Dialog
      ref="participantsDialog"
      width="sm"
      :title="
        t('MESSAGE_REACTIONS.COUNT', {
          emoji: selectedEmoji,
          count: selectedParticipants.length,
        })
      "
      :show-confirm-button="false"
      :show-cancel-button="false"
    >
      <ul class="flex flex-col gap-3">
        <li
          v-for="participant in selectedParticipants"
          :key="participant.participantKey"
          class="flex items-center gap-3 text-sm text-n-slate-12"
        >
          <Avatar
            :src="participant.avatarUrl"
            :name="participant.displayName"
            :size="32"
          />
          <span class="min-w-0 flex-1 break-words">{{
            participant.displayName
          }}</span>
          <span>{{ participant.emoji }}</span>
        </li>
      </ul>
    </Dialog>
  </div>
</template>
