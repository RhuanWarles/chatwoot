<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const props = defineProps({
  conversationId: { type: Number, required: true },
  note: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();
const expanded = ref(false);
const removing = ref(false);

// A mention is saved as a markdown link; the banner only needs the "@Name".
const MENTION_PATTERN = /\[(@[^\]]+)\]\(mention:\/\/[^)]*\)/g;

const text = computed(() => props.note.content.replace(MENTION_PATTERN, '$1'));

const isLong = computed(
  () => text.value.length > 140 || text.value.includes('\n')
);

// A note an agent chose says who pinned it; the latest note, pinned on its own, says who wrote it.
const byLine = computed(() => {
  const { auto, author, pinned_by: pinnedBy } = props.note;
  if (auto) {
    return author?.name
      ? t('CONVERSATION.PINNED_NOTE.LAST_NOTE_BY', { name: author.name })
      : t('CONVERSATION.PINNED_NOTE.LAST_NOTE');
  }
  return pinnedBy?.name
    ? t('CONVERSATION.PINNED_NOTE.PINNED_BY', { name: pinnedBy.name })
    : '';
});

const goToNote = () => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
    messageId: props.note.message_id,
  });
};

const unpin = async () => {
  if (removing.value) return;
  removing.value = true;
  try {
    await store.dispatch('unpinNote', { conversationId: props.conversationId });
  } catch {
    useAlert(t('CONVERSATION.PINNED_NOTE.UNPIN_ERROR'));
  } finally {
    removing.value = false;
  }
};
</script>

<template>
  <div
    class="flex items-start gap-2 px-3 py-2 mx-2 mt-2 text-sm rounded-lg bg-n-amber-3 text-n-amber-12"
    role="note"
    data-test="pinned-note"
  >
    <span class="mt-0.5 i-lucide-pin size-4 shrink-0" aria-hidden="true" />
    <div class="flex-1 min-w-0">
      <p
        class="m-0 whitespace-pre-wrap [overflow-wrap:anywhere]"
        :class="{ 'line-clamp-2': isLong && !expanded }"
        data-test="pinned-note-text"
      >
        {{ text }}
      </p>
      <div
        class="flex flex-wrap items-center gap-3 mt-1 text-xs text-n-amber-11"
      >
        <span v-if="byLine" data-test="pinned-note-by">{{ byLine }}</span>
        <button
          v-if="isLong"
          type="button"
          class="underline"
          data-test="pinned-note-toggle"
          @click="expanded = !expanded"
        >
          {{
            expanded
              ? t('CONVERSATION.PINNED_NOTE.SHOW_LESS')
              : t('CONVERSATION.PINNED_NOTE.SHOW_MORE')
          }}
        </button>
        <button
          type="button"
          class="underline"
          data-test="pinned-note-go"
          @click="goToNote"
        >
          {{ t('CONVERSATION.PINNED_NOTE.GO_TO_NOTE') }}
        </button>
      </div>
    </div>
    <button
      type="button"
      class="flex items-center justify-center rounded size-6 shrink-0 hover:bg-n-alpha-2"
      :disabled="removing"
      :title="t('CONVERSATION.PINNED_NOTE.UNPIN')"
      :aria-label="t('CONVERSATION.PINNED_NOTE.UNPIN')"
      data-test="pinned-note-unpin"
      @click="unpin"
    >
      <span class="text-lg leading-none" aria-hidden="true">×</span>
    </button>
  </div>
</template>
