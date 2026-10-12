import { computed, inject, provide, ref, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import aiTools from 'dashboard/api/aiTools';

const TOOL_EXECUTIONS = Symbol('conversation-tool-executions');

export const provideConversationToolExecutions = () => {
  const chat = useMapGetter('getSelectedChat');
  const accountId = useMapGetter('getCurrentAccountId');
  const executions = ref([]);
  const error = ref(false);
  const loading = ref(false);
  let generation = 0;

  const refresh = async () => {
    const currentGeneration = ++generation;
    const conversationId = chat.value.id;
    if (!conversationId) return;
    loading.value = true;
    error.value = false;
    const items = [];
    try {
      let page = 1;
      let total = 0;
      do {
        const { data } = await aiTools.executions({
          conversation_id: conversationId,
          page,
        });
        if (currentGeneration !== generation) return;
        items.push(...data.executions);
        total = data.meta.total_count;
        page += 1;
      } while (items.length < total);
      executions.value = items;
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
      executions.value = [];
      loading.value = false;
      error.value = false;
      if (chat.value.id) refresh();
    },
    { immediate: true }
  );
  // Existing message realtime updates refresh both views after the agent replies.
  watch(
    () => chat.value.messages?.length,
    (count, previous) => {
      if (count > previous) refresh();
    }
  );

  const state = {
    executions,
    loading,
    error,
    refresh,
    conversationId: computed(() => chat.value.id),
  };
  provide(TOOL_EXECUTIONS, state);
  return state;
};

export const useConversationToolExecutions = () => inject(TOOL_EXECUTIONS);
