<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import aiToolsAPI from 'dashboard/api/aiTools';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const tools = ref([]);
const search = ref('');
const loading = ref(true);
const error = ref('');
const selectedId = computed(() => Number(route.params.toolId) || null);
const filteredTools = computed(() => {
  const query = search.value.trim().toLowerCase();
  return tools.value.filter(tool => !query || String(tool.name || '').toLowerCase().includes(query));
});
const selectTool = tool => router.push({ name: 'ai_tool_edit', params: { toolId: tool.id } });
const createTool = () => router.push({ name: 'ai_tool_new' });
const load = async () => {
  try {
    const { data } = await aiToolsAPI.get();
    tools.value = data.tools || [];
    if (!route.params.toolId && tools.value[0]) selectTool(tools.value[0]);
  } catch {
    error.value = t('AI_TOOLS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
watch(() => route.params.toolId, value => {
  if (value) return;
  if (tools.value[0]) selectTool(tools.value[0]);
});
onMounted(load);
</script>

<template>
  <main class="flex w-full h-full min-h-0 overflow-hidden rounded-xl outline outline-1 outline-n-weak bg-n-solid-1">
    <aside class="flex flex-col w-72 min-h-0 shrink-0 border-e border-n-weak bg-n-solid-2">
      <div class="flex items-center justify-between gap-2 p-4 border-b border-n-weak">
        <div class="flex items-center gap-2 min-w-0">
          <h1 class="text-base font-semibold truncate text-n-slate-12">{{ t('AI_TOOLS.TITLE') }}</h1>
          <span class="text-xs text-n-slate-10">{{ tools.length }}</span>
        </div>
        <Button icon="i-lucide-plus" size="xs" slate ghost :aria-label="t('AI_TOOLS.NEW')" @click="createTool" />
      </div>
      <div class="p-3 border-b border-n-weak">
        <Input v-model="search" :placeholder="t('AI_TOOLS.SEARCH_PLACEHOLDER')" :aria-label="t('AI_TOOLS.SEARCH')" />
      </div>
      <div class="flex-1 min-h-0 p-2 overflow-y-auto">
        <p v-if="loading" class="p-3 text-sm text-n-slate-11">{{ t('AI_TOOLS.LOADING') }}</p>
        <p v-else-if="error" class="p-3 text-sm text-n-ruby-11">{{ error }}</p>
        <button v-for="tool in filteredTools" :key="tool.id" type="button" class="flex flex-col w-full gap-1 px-3 py-2 text-start rounded-lg" :class="tool.id === selectedId ? 'bg-n-alpha-2 outline outline-1 outline-n-weak' : 'hover:bg-n-alpha-2'" @click="selectTool(tool)">
          <span class="text-sm font-medium truncate text-n-slate-12">{{ tool.name }}</span>
          <span class="text-xs text-n-slate-10">{{ tool.configuration?.method || 'GET' }}</span>
        </button>
      </div>
    </aside>
    <section class="flex-1 min-w-0 min-h-0 overflow-y-auto p-6">
      <router-view />
    </section>
  </main>
</template>
