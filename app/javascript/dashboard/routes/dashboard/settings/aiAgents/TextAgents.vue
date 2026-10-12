<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useAccount } from 'dashboard/composables/useAccount';
import TextCredentials from './TextCredentials.vue';

const { t, locale } = useI18n();
const router = useRouter();
const { accountId } = useAccount();
const agents = ref([]);
const textSettings = ref(null);
const loading = ref(true);
const busy = ref(false);
const loadError = ref('');
const actionError = ref('');
const deletion = ref(null);
const memoryDialog = ref(null);
const memoryAgent = ref(null);
const memories = ref([]);
const memoryLoading = ref(false);
const memoryError = ref('');
const deleting = ref(null);
const platformMode = computed(() => textSettings.value?.mode === 'platform');
const effectivePlatformProvider = computed(() => textSettings.value?.platform_provider || '');
const effectivePlatformModel = computed(() => textSettings.value?.platform_model || '');
const providerLabels = computed(() => ({
  openai: t('AI_AGENTS.PROVIDERS.openai'),
  anthropic: t('AI_AGENTS.PROVIDERS.anthropic'),
  gemini: t('AI_AGENTS.PROVIDERS.gemini'),
  openrouter: t('AI_AGENTS.PROVIDERS.openrouter'),
  groq: t('AI_AGENTS.PROVIDERS.groq'),
}));
const formatUpdatedAt = timestamp => timestamp
  ? new Intl.DateTimeFormat(locale.value?.replace('_', '-') || undefined, { dateStyle: 'short', timeStyle: 'short' }).format(new Date(timestamp))
  : '';
const normalizeAgent = agent => ({ ...agent, inboxes: Array.isArray(agent?.inboxes) ? agent.inboxes : [] });

const load = async () => {
  loading.value = true;
  loadError.value = '';
  try {
    const { data } = await aiAgentsAPI.get();
    agents.value = (data.agents || []).map(normalizeAgent);
    textSettings.value = data.text;
  } catch {
    loadError.value = t('AI_AGENTS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
const openEditor = agent => router.push({
  name: agent ? 'ai_agent_edit' : 'ai_agent_new',
  params: { accountId: accountId.value, ...(agent ? { agentId: agent.id } : {}) },
  query: { type: 'text' },
});
const errorText = error => error.response?.data?.error === 'inbox_conflict'
  ? t('AI_AGENTS.INBOX_CONFLICT')
  : t('AI_AGENTS.SAVE_ERROR');
const toggle = async agent => {
  if (busy.value) return;
  busy.value = true;
  actionError.value = '';
  try {
    const { data } = await aiAgentsAPI.update(agent.id, { ai_agent: { active: !agent.active } });
    agents.value = agents.value.map(item => item.id === data.id ? normalizeAgent(data) : item);
    window.dispatchEvent(new Event('saas-ai-credit-status-changed'));
  } catch (error) {
    actionError.value = errorText(error);
  } finally {
    busy.value = false;
  }
};
const requestDelete = agent => {
  deleting.value = agent;
  actionError.value = '';
  deletion.value.open();
};
const openMemories = async agent => {
  memoryAgent.value = agent;
  memories.value = [];
  memoryError.value = '';
  memoryDialog.value.open();
  memoryLoading.value = true;
  try {
    const { data } = await aiAgentsAPI.memories(agent.id);
    memories.value = Array.isArray(data) ? data : [];
  } catch {
    memoryError.value = t('AI_AGENTS.MEMORY_LOAD_ERROR');
  } finally {
    memoryLoading.value = false;
  }
};
const clearMemory = async memory => {
  if (memoryLoading.value) return;
  memoryLoading.value = true;
  try {
    await aiAgentsAPI.clearMemory(memoryAgent.value.id, memory.contact_id);
    memories.value = memories.value.filter(item => item.id !== memory.id);
  } catch {
    memoryError.value = t('AI_AGENTS.MEMORY_CLEAR_ERROR');
  } finally {
    memoryLoading.value = false;
  }
};
const remove = async () => {
  if (busy.value || !deleting.value) return;
  busy.value = true;
  try {
    await aiAgentsAPI.delete(deleting.value.id);
    agents.value = agents.value.filter(item => item.id !== deleting.value.id);
    deletion.value.close();
    window.dispatchEvent(new Event('saas-ai-credit-status-changed'));
  } catch {
    actionError.value = t('AI_AGENTS.DELETE_ERROR');
  } finally {
    busy.value = false;
  }
};
onMounted(load);
</script>

<template>
  <section class="flex flex-col min-w-0">
    <header class="flex flex-wrap items-center justify-between gap-4 mb-6">
      <h2 class="text-heading-3 text-n-slate-12">{{ t('AI_HUB.TEXT') }}</h2>
      <Button :label="t('AI_HUB.NEW_TEXT')" icon="i-lucide-plus" :disabled="loading || !!loadError || busy" @click="openEditor()" />
    </header>
    <p class="mb-4 text-sm text-n-slate-11">{{ t('AI_AGENTS.CONFIG_ONLY') }}</p>
    <p v-if="loading" role="status" class="text-n-slate-11">{{ t('AI_AGENTS.LOADING') }}</p>
    <div v-else-if="loadError" role="alert" class="flex items-center gap-3 text-n-ruby-9">{{ loadError }}<Button :label="t('AI_AGENTS.RETRY')" @click="load" /></div>
    <div v-else class="flex flex-col gap-3">
      <p v-if="actionError" role="alert" class="text-sm text-n-ruby-9">{{ actionError }}</p>
      <p v-if="!agents.length" class="text-n-slate-11">{{ t('AI_AGENTS.EMPTY') }}</p>
      <article v-for="agent in agents" :key="agent.id" class="flex flex-wrap justify-between gap-4 p-4 rounded-lg bg-n-solid-2">
        <div class="min-w-0">
          <h2 class="font-medium break-words text-n-slate-12">{{ agent.name }}</h2>
          <p class="text-sm text-n-slate-11">{{ agent.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE') }}</p>
          <p v-if="platformMode" class="text-sm text-n-slate-11">{{ t('AI_AGENTS.PLATFORM_MODE') }} · {{ effectivePlatformProvider || t('AI_AGENTS.NOT_CONFIGURED') }} · {{ effectivePlatformModel || t('AI_AGENTS.NOT_CONFIGURED') }}</p>
          <p v-else class="text-sm break-all text-n-slate-11">{{ providerLabels[agent.provider] }} · {{ agent.model }}</p>
          <p class="text-sm text-n-slate-11">{{ t('AI_AGENTS.INBOXES') }}: {{ agent.inboxes.map(inbox => inbox.name).join(', ') || t('AI_AGENTS.NO_INBOXES') }}</p>
          <p class="text-xs text-n-slate-11">{{ t('AI_AGENTS.UPDATED') }}: {{ formatUpdatedAt(agent.updated_at) }}</p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Button variant="ghost" :label="t('AI_PLAYGROUND.OPEN')" :disabled="busy" @click="router.push({ name: 'ai_agent_playground', params: { accountId: accountId.value, agentId: agent.id } })" />
          <Button variant="ghost" :label="t('AI_AGENTS.MEMORIES')" :disabled="busy" @click="openMemories(agent)" />
          <Button variant="ghost" :label="t('AI_AGENTS.EDIT')" :disabled="busy" @click="openEditor(agent)" />
          <Button variant="ghost" :label="agent.active ? t('AI_AGENTS.DEACTIVATE') : t('AI_AGENTS.ACTIVATE')" :disabled="busy" @click="toggle(agent)" />
          <Button variant="ghost" color="ruby" :label="t('AI_AGENTS.DELETE')" :disabled="busy" @click="requestDelete(agent)" />
        </div>
      </article>
    </div>
    <TextCredentials class="mt-6" @saved="load" />
    <Dialog ref="memoryDialog" width="2xl" :title="t('AI_AGENTS.MEMORIES')" :cancel-button-label="t('AI_AGENTS.CLOSE')">
      <div class="flex flex-col gap-3 max-h-[65vh] overflow-y-auto">
        <p v-if="memoryError" role="alert" class="text-sm text-n-ruby-9">{{ memoryError }}</p>
        <p v-if="memoryLoading" class="text-sm text-n-slate-11">{{ t('AI_AGENTS.LOADING') }}</p>
        <p v-else-if="!memories.length" class="text-sm text-n-slate-11">{{ t('AI_AGENTS.NO_MEMORIES') }}</p>
        <article v-for="memory in memories" :key="memory.id" class="p-3 rounded-lg bg-n-solid-2"><div class="flex items-center justify-between gap-3"><strong class="text-sm text-n-slate-12">{{ memory.contact_name || memory.contact_id }}</strong><Button variant="ghost" color="ruby" :label="t('AI_AGENTS.CLEAR_MEMORY')" @click="clearMemory(memory)" /></div><p class="mt-2 text-sm whitespace-pre-wrap text-n-slate-11">{{ memory.content }}</p></article>
      </div>
    </Dialog>
    <Dialog ref="deletion" type="alert" :title="t('AI_AGENTS.DELETE')" :description="t('AI_AGENTS.DELETE_CONFIRM', { name: deleting?.name })" :is-loading="busy" :disable-confirm-button="busy" :confirm-button-label="t('AI_AGENTS.DELETE')" :cancel-button-label="t('AI_AGENTS.CANCEL')" @confirm="remove"><p v-if="actionError" role="alert" class="text-sm text-n-ruby-9">{{ actionError }}</p></Dialog>
  </section>
</template>
