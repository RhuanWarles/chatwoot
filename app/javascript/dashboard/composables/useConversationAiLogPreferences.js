import { computed, inject, provide, ref, watch } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import ConversationApi from 'dashboard/api/inbox/conversation';

const AI_LOG_PREFERENCES = Symbol('conversation-ai-log-preferences');
const DEFAULT_PREFERENCES = Object.freeze({
  show_tool_executions: false,
  show_knowledge_retrievals: false,
});

export const provideConversationAiLogPreferences = () => {
  const chat = useMapGetter('getSelectedChat');
  const store = useStore();
  const saving = ref(false);
  const preferences = computed(() => ({
    ...DEFAULT_PREFERENCES,
    ...(chat.value.additional_attributes?.ai_timeline_preferences || {}),
  }));

  const update = async (key, value) => {
    const next = { ...preferences.value, [key]: value };
    saving.value = true;
    try {
      const { data } = await ConversationApi.updateAiTimelinePreferences({
        conversationId: chat.value.id,
        preferences: next,
      });
      store.dispatch('updateConversation', data);
    } finally {
      saving.value = false;
    }
  };

  watch(() => chat.value.id, () => { saving.value = false; });

  const state = {
    preferences,
    saving,
    update,
    showToolExecutions: computed(() => preferences.value.show_tool_executions),
    showKnowledgeRetrievals: computed(() => preferences.value.show_knowledge_retrievals),
  };
  provide(AI_LOG_PREFERENCES, state);
  return state;
};

export const useConversationAiLogPreferences = () => inject(AI_LOG_PREFERENCES);

