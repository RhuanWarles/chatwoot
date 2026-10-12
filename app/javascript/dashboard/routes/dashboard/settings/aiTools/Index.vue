<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import aiToolsAPI from 'dashboard/api/aiTools';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const { t } = useI18n();
const router = useRouter();
const tools = ref([]);
const agents = ref([]);
const loading = ref(true);
const error = ref('');
const busy = ref(false);
const deleting = ref(null);
const deletion = ref(null);

const linkedAgents = tool =>
  agents.value.filter(agent =>
    (agent.tools || []).some(assignedTool => assignedTool.id === tool.id)
  );
const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    const [toolsResponse, agentsResponse] = await Promise.all([
      aiToolsAPI.get(),
      aiAgentsAPI.get(),
    ]);
    tools.value = toolsResponse.data.tools || [];
    agents.value = agentsResponse.data.agents || [];
  } catch {
    error.value = t('AI_TOOLS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
const openEditor = tool => router.push(tool ? { name: 'ai_tool_edit', params: { toolId: tool.id } } : { name: 'ai_tool_new' });
const toggle = async tool => {
  if (busy.value) return;
  busy.value = true;
  try {
    const { data } = await aiToolsAPI.update(tool.id, {
      ai_tool: { active: !tool.active },
    });
    onSaved(data);
  } catch {
    error.value = t('AI_TOOLS.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
};
const requestDelete = tool => {
  deleting.value = tool;
  deletion.value.open();
};
const remove = async () => {
  if (!deleting.value || busy.value) return;
  busy.value = true;
  try {
    await aiToolsAPI.delete(deleting.value.id);
    tools.value = tools.value.filter(tool => tool.id !== deleting.value.id);
    deletion.value.close();
  } catch {
    error.value = t('AI_TOOLS.DELETE_ERROR');
  } finally {
    busy.value = false;
  }
};
const method = tool => tool.configuration?.method || 'GET';
onMounted(load);
</script>

<template>
  <main class="flex flex-col w-full min-w-0 gap-6">
    <header class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">{{ t('AI_TOOLS.TITLE') }}</h1>
        <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.SUBTITLE') }}</p>
      </div>
      <Button :label="t('AI_TOOLS.NEW')" icon="i-lucide-plus" :disabled="loading || busy" @click="openEditor()" />
    </header>
    <nav class="flex gap-2 border-b border-n-weak">
      <Button variant="faded" :label="t('AI_TOOLS.TOOLS_TAB')" :disabled="true" />
      <Button variant="ghost" :label="t('AI_TOOLS.LOGS_TAB')" @click="router.push({ name: 'ai_tool_logs' })" />
    </nav>
    <p v-if="loading" role="status" class="text-n-slate-11">{{ t('AI_TOOLS.LOADING') }}</p>
    <div v-else-if="error" class="flex items-center gap-3 text-n-ruby-9" role="alert">
      {{ error }} <Button :label="t('AI_TOOLS.RETRY')" @click="load" />
    </div>
    <div v-else-if="!tools.length" class="flex flex-col items-start gap-4 p-6 rounded-lg bg-n-solid-2">
      <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.EMPTY') }}</p>
      <Button :label="t('AI_TOOLS.NEW')" icon="i-lucide-plus" @click="openEditor()" />
    </div>
    <div v-else class="flex flex-col gap-3">
      <article v-for="tool in tools" :key="tool.id" class="flex flex-wrap items-start justify-between gap-4 p-4 rounded-lg bg-n-solid-2">
        <div class="min-w-0">
          <h2 class="font-medium break-words text-n-slate-12">{{ tool.name }}</h2>
          <p class="text-sm text-n-slate-11">{{ tool.slug }} · {{ tool.tool_type }} · {{ method(tool) }}</p>
          <p class="text-sm text-n-slate-11">{{ tool.active ? t('AI_TOOLS.ACTIVE') : t('AI_TOOLS.INACTIVE') }}</p>
          <p class="text-sm text-n-slate-11">
            {{ t('AI_TOOLS.LINKED_AGENTS') }}:
            {{ linkedAgents(tool).map(agent => agent.name).join(', ') || t('AI_TOOLS.NONE') }}
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Button variant="ghost" :label="t('AI_TOOLS.EDIT')" :disabled="busy" @click="openEditor(tool)" />
          <Button variant="ghost" :label="tool.active ? t('AI_TOOLS.DEACTIVATE') : t('AI_TOOLS.ACTIVATE')" :disabled="busy" @click="toggle(tool)" />
          <Button variant="ghost" color="ruby" :label="t('AI_TOOLS.DELETE')" :disabled="busy" @click="requestDelete(tool)" />
        </div>
      </article>
    </div>
    <Dialog ref="deletion" type="alert" :title="t('AI_TOOLS.DELETE')" :description="t('AI_TOOLS.DELETE_CONFIRM', { name: deleting?.name })" :is-loading="busy" :disable-confirm-button="busy" :confirm-button-label="t('AI_TOOLS.DELETE')" :cancel-button-label="t('AI_TOOLS.CANCEL')" @confirm="remove" />
  </main>
</template>
