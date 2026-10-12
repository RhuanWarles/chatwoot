import { computed, inject, provide, ref, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import knowledgeRetrievals from 'dashboard/api/knowledgeRetrievals';

const KNOWLEDGE_RETRIEVALS = Symbol('conversation-knowledge-retrievals');

export const provideConversationKnowledgeRetrievals = () => {
  const chat = useMapGetter('getSelectedChat');
  const accountId = useMapGetter('getCurrentAccountId');
  const retrievals = ref([]);
  const loading = ref(false);
  const error = ref(false);
  const selectedRetrievalId = ref(null);
  let generation = 0;

  const refresh = async () => {
    const currentGeneration = ++generation;
    const conversationId = chat.value.id;
    if (!conversationId) return;

    loading.value = true;
    error.value = false;
    try {
      const { data } = await knowledgeRetrievals.index(conversationId);
      if (currentGeneration === generation) retrievals.value = data.retrievals;
    } catch {
      if (currentGeneration === generation) error.value = true;
    } finally {
      if (currentGeneration === generation) loading.value = false;
    }
  };

  watch(
    [accountId, () => chat.value.id],
    () => {
      generation += 1;
      retrievals.value = [];
      selectedRetrievalId.value = null;
      error.value = false;
      if (chat.value.id) refresh();
    },
    { immediate: true }
  );

  watch(() => chat.value.messages?.length, (count, previous) => {
    if (count > previous) refresh();
  });

  const state = {
    retrievals,
    loading,
    error,
    refresh,
    conversationId: computed(() => chat.value.id),
    selectedRetrievalId,
    openRetrieval: id => {
      selectedRetrievalId.value = id;
    },
  };
  provide(KNOWLEDGE_RETRIEVALS, state);
  return state;
};

export const useConversationKnowledgeRetrievals = () =>
  inject(KNOWLEDGE_RETRIEVALS);
