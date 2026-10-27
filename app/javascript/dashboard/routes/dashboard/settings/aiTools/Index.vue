<script setup>
import { computed, onActivated, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import aiToolsAPI from 'dashboard/api/aiTools';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();
const router = useRouter();
const tools = ref([]);
const agents = ref([]);
const loading = ref(true);
const error = ref('');
const busy = ref(false);
const deleting = ref(null);
const deletion = ref(null);
const search = ref('');
const status = ref('all');

const linkedAgents = tool =>
  agents.value.filter(agent =>
    (agent.tools || []).some(assignedTool => assignedTool.id === tool.id)
  );

const filteredTools = computed(() => {
  const query = search.value.trim().toLowerCase();
  return tools.value.filter(tool => {
    const matchesStatus =
      status.value === 'all' ||
      (status.value === 'active' ? tool.active : !tool.active);
    const matchesSearch =
      !query ||
      [
        tool.name,
        tool.description,
        tool.configuration?.url,
        tool.configuration?.method,
      ].some(value =>
        String(value || '')
          .toLowerCase()
          .includes(query)
      );
    return matchesStatus && matchesSearch;
  });
});

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

const openEditor = tool =>
  router.push(
    tool
      ? { name: 'ai_tool_edit', params: { toolId: tool.id } }
      : { name: 'ai_tool_new' }
  );

const openLogs = () => router.push({ name: 'ai_tool_logs' });

const onSaved = tool => {
  tools.value = tools.value.map(item => (item.id === tool.id ? tool : item));
};

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
const url = tool => tool.configuration?.url || t('AI_TOOLS.NO_URL');
const description = tool => tool.description || t('AI_TOOLS.NO_DESCRIPTION');

onMounted(load);
onActivated(() => {
  if (!loading.value) load();
});
</script>

<template>
  <main class="flex flex-col w-full min-w-0 gap-6 pb-8">
    <header class="flex flex-wrap items-start justify-between gap-4">
      <div class="min-w-0">
        <p
          class="mb-1 text-xs font-medium tracking-wide uppercase text-n-slate-11"
        >
          {{ t('AI_HUB.TITLE') }}
        </p>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          {{ t('AI_TOOLS.TITLE') }}
        </h1>
        <p class="max-w-2xl mt-1 text-sm text-n-slate-11">
          {{ t('AI_TOOLS.SUBTITLE') }}
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <Button
          variant="faded"
          :label="t('AI_TOOLS.LOGS_TAB')"
          icon="i-lucide-scroll-text"
          @click="openLogs"
        />
        <Button
          :label="t('AI_TOOLS.NEW')"
          icon="i-lucide-plus"
          :disabled="loading || busy"
          @click="openEditor()"
        />
      </div>
    </header>

    <nav
      class="flex gap-1 p-1 rounded-xl bg-n-surface-1 outline outline-1 outline-n-container"
      :aria-label="t('AI_TOOLS.NAVIGATION')"
    >
      <Button variant="faded" :label="t('AI_TOOLS.TOOLS_TAB')" disabled />
      <Button
        variant="ghost"
        :label="t('AI_TOOLS.LOGS_TAB')"
        @click="openLogs"
      />
    </nav>

    <section
      v-if="!loading && !error && tools.length"
      class="flex flex-wrap items-end gap-3 p-4 rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <Input
        v-model="search"
        class="flex-1 min-w-56"
        :label="t('AI_TOOLS.SEARCH')"
        :placeholder="t('AI_TOOLS.SEARCH_PLACEHOLDER')"
      />
      <label class="flex flex-col gap-1 min-w-44 text-sm text-n-slate-12">
        {{ t('AI_TOOLS.STATUS_FILTER') }}
        <select
          v-model="status"
          class="h-10 px-3 rounded-lg outline outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12"
        >
          <option value="all">{{ t('AI_TOOLS.ALL_STATUS') }}</option>
          <option value="active">{{ t('AI_TOOLS.FILTER_ACTIVE') }}</option>
          <option value="inactive">{{ t('AI_TOOLS.FILTER_INACTIVE') }}</option>
        </select>
      </label>
      <p class="w-full m-0 text-xs text-n-slate-11">
        {{ t('AI_TOOLS.RESULT_COUNT', { count: filteredTools.length }) }}
      </p>
    </section>

    <p v-if="loading" role="status" class="text-n-slate-11">
      {{ t('AI_TOOLS.LOADING') }}
    </p>
    <div
      v-else-if="error"
      class="flex items-center gap-3 text-n-ruby-9"
      role="alert"
    >
      {{ error }} <Button :label="t('AI_TOOLS.RETRY')" @click="load" />
    </div>
    <div
      v-else-if="!tools.length"
      class="flex flex-col items-start gap-4 p-8 rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <div>
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('AI_TOOLS.EMPTY') }}
        </h2>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ t('AI_TOOLS.EMPTY_HELP') }}
        </p>
      </div>
      <Button
        :label="t('AI_TOOLS.NEW')"
        icon="i-lucide-plus"
        @click="openEditor()"
      />
    </div>
    <div
      v-else-if="!filteredTools.length"
      class="p-8 text-center rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.EMPTY_FILTERED') }}</p>
    </div>
    <div v-else class="grid grid-cols-1 gap-4 md:grid-cols-2">
      <article
        v-for="tool in filteredTools"
        :key="tool.id"
        class="flex flex-col min-w-0 gap-4 p-5 rounded-2xl outline outline-1 outline-n-container bg-n-surface-1 shadow-sm transition-shadow hover:shadow-md"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h2
                class="m-0 text-base font-semibold break-words text-n-slate-12"
              >
                {{ tool.name }}
              </h2>
              <span
                class="px-2 py-0.5 text-xs rounded-full"
                :class="
                  tool.active
                    ? 'text-n-emerald-11 bg-n-emerald-2'
                    : 'text-n-slate-11 bg-n-solid-2'
                "
              >
                {{
                  tool.active ? t('AI_TOOLS.ACTIVE') : t('AI_TOOLS.INACTIVE')
                }}
              </span>
            </div>
            <p class="mt-1 text-sm break-words text-n-slate-11">
              {{ description(tool) }}
            </p>
          </div>
          <details class="relative shrink-0">
            <summary
              class="flex items-center justify-center w-8 h-8 list-none rounded-lg cursor-pointer text-n-slate-11 hover:bg-n-alpha-2"
              :aria-label="t('AI_TOOLS.MORE')"
            >
              <span class="i-lucide-ellipsis text-lg" aria-hidden="true" />
            </summary>
            <div
              class="absolute end-0 z-10 flex flex-col w-40 gap-1 p-2 mt-1 rounded-lg shadow-lg bg-n-solid-1 outline outline-1 outline-n-weak"
            >
              <Button
                variant="ghost"
                justify="start"
                :label="
                  tool.active
                    ? t('AI_TOOLS.DEACTIVATE')
                    : t('AI_TOOLS.ACTIVATE')
                "
                :disabled="busy"
                @click="toggle(tool)"
              />
              <Button
                variant="ghost"
                justify="start"
                color="ruby"
                :label="t('AI_TOOLS.DELETE')"
                :disabled="busy"
                @click="requestDelete(tool)"
              />
            </div>
          </details>
        </div>
        <div class="flex flex-wrap items-center gap-2 text-xs text-n-slate-11">
          <span class="px-2 py-1 font-medium rounded bg-n-solid-2">{{
            method(tool)
          }}</span>
          <span class="max-w-full truncate" :title="url(tool)">{{
            url(tool)
          }}</span>
        </div>
        <div class="flex items-center gap-2 text-sm text-n-slate-11">
          <span class="i-lucide-users" aria-hidden="true" />
          <span>
            {{
              t('AI_TOOLS.ASSISTANTS_COUNT', {
                count: linkedAgents(tool).length,
              })
            }}
          </span>
        </div>
        <div
          class="flex flex-wrap items-center gap-2 pt-2 mt-auto border-t border-n-weak"
        >
          <Button
            variant="ghost"
            :label="t('AI_TOOLS.EDIT')"
            :disabled="busy"
            @click="openEditor(tool)"
          />
          <Button
            variant="ghost"
            :label="t('AI_TOOLS.OPEN_LOGS')"
            :disabled="busy"
            @click="openLogs"
          />
        </div>
      </article>
    </div>
    <Dialog
      ref="deletion"
      type="alert"
      :title="t('AI_TOOLS.DELETE')"
      :description="t('AI_TOOLS.DELETE_CONFIRM', { name: deleting?.name })"
      :is-loading="busy"
      :disable-confirm-button="busy"
      :confirm-button-label="t('AI_TOOLS.DELETE')"
      :cancel-button-label="t('AI_TOOLS.CANCEL')"
      @confirm="remove"
    />
  </main>
</template>
