<script setup>
import { computed, ref, watch } from 'vue';
import { useConversationKnowledgeRetrievals } from 'dashboard/composables/useConversationKnowledgeRetrievals';
import KnowledgeRetrievalItem from './KnowledgeRetrievalItem.vue';

const { retrievals, loading, error, refresh, openRetrieval } = useConversationKnowledgeRetrievals();
const expanded = ref(false);
const visible = computed(() => expanded.value ? retrievals.value : retrievals.value.slice(0, 5));
watch(retrievals, () => { if (!retrievals.value.length) expanded.value = false; });
</script>

<template>
  <div class="p-2 min-w-0">
    <p v-if="error" class="p-2 text-xs text-n-ruby-11">{{ $t('CONVERSATION.KNOWLEDGE_RETRIEVAL.ERROR') }}</p>
    <button v-if="error" class="p-2 text-xs text-n-blue-11" @click="refresh">{{ $t('CONVERSATION.KNOWLEDGE_RETRIEVAL.RETRY') }}</button>
    <p v-else-if="loading && !retrievals.length" class="p-2 text-xs text-n-slate-11">{{ $t('CONVERSATION.KNOWLEDGE_RETRIEVAL.LOADING') }}</p>
    <p v-else-if="!retrievals.length" class="p-2 text-xs text-n-slate-11">{{ $t('CONVERSATION.KNOWLEDGE_RETRIEVAL.EMPTY') }}</p>
    <div :class="expanded ? 'max-h-80 overflow-y-auto' : ''">
      <KnowledgeRetrievalItem v-for="retrieval in visible" :key="retrieval.id" :retrieval="retrieval" @select="openRetrieval(retrieval.id)" />
    </div>
    <button v-if="retrievals.length > 5" class="p-2 text-xs text-n-blue-11" @click="expanded = !expanded">
      {{ expanded ? $t('CONVERSATION.KNOWLEDGE_RETRIEVAL.LESS') : $t('CONVERSATION.KNOWLEDGE_RETRIEVAL.ALL', { count: retrievals.length }) }}
    </button>
  </div>
</template>

