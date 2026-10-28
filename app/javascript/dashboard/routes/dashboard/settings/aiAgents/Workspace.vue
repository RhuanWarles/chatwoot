<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import aiAgentsAPI from 'dashboard/api/aiAgents';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const agents = ref([]);
const search = ref('');
const loading = ref(true);
const error = ref('');
const selectedId = computed(() => Number(route.params.agentId) || null);
const filteredAgents = computed(() => {
  const query = search.value.trim().toLowerCase();
  return agents.value.filter(agent => !query || agent.name.toLowerCase().includes(query));
});
const selectAgent = agent => router.push({ name: 'ai_agent_edit', params: { agentId: agent.id }, query: { type: 'text' } });
const createAgent = () => router.push({ name: 'ai_agent_new', query: { type: 'text' } });
const load = async () => {
  try {
    const { data } = await aiAgentsAPI.get();
    agents.value = data.agents || [];
    if (!route.params.agentId && agents.value[0]) selectAgent(agents.value[0]);
  } catch {
    error.value = t('AI_AGENTS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
watch(() => route.params.agentId, value => {
  if (!value && agents.value[0]) selectAgent(agents.value[0]);
});
onMounted(load);
</script>

<template>
  <main class="flex w-full h-full min-h-0 overflow-hidden rounded-xl outline outline-1 outline-n-weak bg-n-solid-1">
    <aside class="flex flex-col w-72 min-h-0 shrink-0 border-e border-n-weak bg-n-solid-2">
      <div class="flex items-center justify-between gap-2 p-4 border-b border-n-weak">
        <div class="flex items-center gap-2 min-w-0">
          <h1 class="text-base font-semibold truncate text-n-slate-12">{{ t('AI_AGENTS.TITLE') }}</h1>
          <span class="text-xs text-n-slate-10">{{ agents.length }}</span>
        </div>
        <Button icon="i-lucide-plus" size="xs" slate ghost :aria-label="t('AI_AGENTS.NEW')" @click="createAgent" />
      </div>
      <div class="p-3 border-b border-n-weak">
        <Input v-model="search" :placeholder="t('AI_AGENTS.SEARCH')" :aria-label="t('AI_AGENTS.SEARCH')" />
      </div>
      <div class="flex-1 min-h-0 p-2 overflow-y-auto">
        <p v-if="loading" class="p-3 text-sm text-n-slate-11">{{ t('AI_AGENTS.LOADING') }}</p>
        <p v-else-if="error" class="p-3 text-sm text-n-ruby-11">{{ error }}</p>
        <button v-for="agent in filteredAgents" :key="agent.id" type="button" class="flex flex-col w-full gap-1 px-3 py-2 text-start rounded-lg" :class="agent.id === selectedId ? 'bg-n-alpha-2 outline outline-1 outline-n-weak' : 'hover:bg-n-alpha-2'" @click="selectAgent(agent)">
          <span class="text-sm font-medium truncate text-n-slate-12">{{ agent.name }}</span>
          <span class="text-xs text-n-slate-10">{{ agent.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE') }}</span>
        </button>
      </div>
    </aside>
    <section class="flex-1 min-w-0 min-h-0 overflow-y-auto p-6">
      <router-view />
    </section>
  </main>
</template>
