<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import aiToolsAPI from 'dashboard/api/aiTools';
import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import ToolExecutionDetailsDialog from 'dashboard/components-next/ai-tools/ToolExecutionDetailsDialog.vue';

const { t } = useI18n();
const router = useRouter();
const executions = ref([]);
const agents = ref([]);
const tools = ref([]);
const selected = ref(null);
const loading = ref(true);
const error = ref('');
const page = ref(1);
const total = ref(0);
const filters = ref({
  ai_agent_id: '',
  ai_tool_id: '',
  status: '',
  source: '',
  period: '7d',
});

const statusOptions = computed(() => [
  { value: '', label: t('AI_TOOLS.LOGS_ALL') },
  { value: 'completed', label: t('AI_TOOLS.LOGS_SUCCESS') },
  { value: 'failed', label: t('AI_TOOLS.LOGS_FAILED') },
]);
const sourceOptions = computed(() => [
  { value: '', label: t('AI_TOOLS.LOGS_ALL') },
  { value: 'conversation', label: t('AI_TOOLS.LOGS_CONVERSATION') },
  { value: 'playground', label: t('AI_TOOLS.LOGS_PLAYGROUND') },
  { value: 'test', label: t('AI_TOOLS.LOGS_TEST') },
  { value: 'unknown', label: t('AI_TOOLS.LOGS_UNKNOWN') },
]);
const periodOptions = computed(() => [
  { value: 'today', label: t('AI_TOOLS.LOGS_TODAY') },
  { value: '7d', label: t('AI_TOOLS.LOGS_LAST_7_DAYS') },
  { value: '30d', label: t('AI_TOOLS.LOGS_LAST_30_DAYS') },
]);
const formatDate = value =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));
const statusLabel = status =>
  status === 'completed'
    ? t('AI_TOOLS.LOGS_SUCCESS')
    : t('AI_TOOLS.LOGS_FAILED');
const sourceLabel = source =>
  sourceOptions.value.find(option => option.value === source)?.label || source;
const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    const [response, agentsResponse, toolsResponse] = await Promise.all([
      aiToolsAPI.executions({ ...filters.value, page: page.value }),
      agents.value.length
        ? Promise.resolve({ data: { agents: agents.value } })
        : aiAgentsAPI.get(),
      tools.value.length
        ? Promise.resolve({ data: { tools: tools.value } })
        : aiToolsAPI.get(),
    ]);
    executions.value = response.data.executions || [];
    total.value = response.data.meta?.total_count || 0;
    agents.value = agentsResponse.data.agents || agents.value;
    tools.value = toolsResponse.data.tools || tools.value;
  } catch {
    error.value = t('AI_TOOLS.LOGS_LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
const applyFilters = () => {
  if (page.value === 1) load();
  else page.value = 1;
};
const openConversation = id => {
  if (id)
    router.push({
      name: 'inbox_conversation',
      params: { conversation_id: id },
    });
};
const openDetails = item => {
  selected.value = item.id;
};
watch(page, load);
onMounted(load);
</script>

<template>
  <main class="flex flex-col w-full min-w-0 gap-6">
    <header class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('AI_TOOLS.LOGS_TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.LOGS_SUBTITLE') }}</p>
      </div>
      <Button
        variant="ghost"
        :label="t('AI_TOOLS.TOOLS_TAB')"
        @click="router.push({ name: 'ai_tools_settings' })"
      />
    </header>
    <section
      class="flex flex-wrap gap-3 p-4 rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <div class="flex flex-col gap-1 text-sm text-n-slate-12">
        <p class="mb-0">{{ t('AI_TOOLS.LOGS_AGENT') }}</p>
        <select
          v-model="filters.ai_agent_id"
          :aria-label="t('AI_TOOLS.LOGS_AGENT')"
          class="h-10 px-3 rounded-lg bg-n-solid-1 border border-n-weak"
          @change="applyFilters"
        >
          <option value="">{{ t('AI_TOOLS.LOGS_ALL') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </div>
      <div class="flex flex-col gap-1 text-sm text-n-slate-12">
        <p class="mb-0">{{ t('AI_TOOLS.LOGS_TOOL') }}</p>
        <select
          v-model="filters.ai_tool_id"
          :aria-label="t('AI_TOOLS.LOGS_TOOL')"
          class="h-10 px-3 rounded-lg bg-n-solid-1 border border-n-weak"
          @change="applyFilters"
        >
          <option value="">{{ t('AI_TOOLS.LOGS_ALL') }}</option>
          <option v-for="tool in tools" :key="tool.id" :value="tool.id">
            {{ tool.name }}
          </option>
        </select>
      </div>
      <div class="flex flex-col gap-1 text-sm text-n-slate-12">
        <p class="mb-0">{{ t('AI_TOOLS.LOGS_STATUS') }}</p>
        <select
          v-model="filters.status"
          :aria-label="t('AI_TOOLS.LOGS_STATUS')"
          class="h-10 px-3 rounded-lg bg-n-solid-1 border border-n-weak"
          @change="applyFilters"
        >
          <option
            v-for="option in statusOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </div>
      <div class="flex flex-col gap-1 text-sm text-n-slate-12">
        <p class="mb-0">{{ t('AI_TOOLS.LOGS_SOURCE') }}</p>
        <select
          v-model="filters.source"
          :aria-label="t('AI_TOOLS.LOGS_SOURCE')"
          class="h-10 px-3 rounded-lg bg-n-solid-1 border border-n-weak"
          @change="applyFilters"
        >
          <option
            v-for="option in sourceOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </div>
      <div class="flex flex-col gap-1 text-sm text-n-slate-12">
        <p class="mb-0">{{ t('AI_TOOLS.LOGS_PERIOD') }}</p>
        <select
          v-model="filters.period"
          :aria-label="t('AI_TOOLS.LOGS_PERIOD')"
          class="h-10 px-3 rounded-lg bg-n-solid-1 border border-n-weak"
          @change="applyFilters"
        >
          <option
            v-for="option in periodOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </div>
    </section>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-9">{{ error }}</p>
    <p v-if="loading" role="status" class="text-sm text-n-slate-11">
      {{ t('AI_TOOLS.LOADING') }}
    </p>
    <div
      v-else-if="!executions.length"
      class="p-8 text-center rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <p class="text-sm text-n-slate-12">{{ t('AI_TOOLS.LOGS_EMPTY') }}</p>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ t('AI_TOOLS.LOGS_EMPTY_HELP') }}
      </p>
    </div>
    <div
      v-else
      class="overflow-x-auto rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-n-slate-11 border-b border-n-weak">
            <th class="p-3">{{ t('AI_TOOLS.LOGS_DATE') }}</th>
            <th class="p-3">{{ t('AI_TOOLS.LOGS_AGENT') }}</th>
            <th class="p-3">{{ t('AI_TOOLS.LOGS_TOOL') }}</th>
            <th class="p-3">{{ t('AI_TOOLS.LOGS_STATUS') }}</th>
            <th class="p-3">{{ t('AI_TOOLS.LOGS_HTTP') }}</th>
            <th class="p-3">{{ t('AI_TOOLS.LOGS_DURATION') }}</th>
            <th class="p-3">{{ t('AI_TOOLS.LOGS_SOURCE') }}</th>
            <th class="p-3">{{ t('AI_TOOLS.LOGS_CONVERSATION') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="item in executions"
            :key="item.id"
            class="cursor-pointer border-b border-n-weak last:border-0 hover:bg-n-solid-1"
            @click="openDetails(item)"
          >
            <td class="p-3 whitespace-nowrap">
              {{ formatDate(item.created_at) }}
            </td>
            <td class="p-3">{{ item.agent.name }}</td>
            <td class="p-3">{{ item.tool.name }}</td>
            <td class="p-3">
              <div
                :class="
                  item.status === 'completed'
                    ? 'text-n-emerald-11'
                    : 'text-n-ruby-11'
                "
              >
                {{ statusLabel(item.status) }}
              </div>
            </td>
            <td class="p-3">{{ item.response_status || '—' }}</td>
            <td class="p-3">
              {{ item.duration_ms ? `${item.duration_ms} ms` : '—' }}
            </td>
            <td class="p-3">{{ sourceLabel(item.source) }}</td>
            <td class="p-3">
              <button
                v-if="item.conversation_display_id"
                class="text-n-brand"
                @click.stop="openConversation(item.conversation_display_id)"
              >
                #{{ item.conversation_display_id }}
              </button>
              <span v-else>—</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <PaginationFooter
      v-if="total"
      v-model:current-page="page"
      :total-items="total"
      :items-per-page="25"
    />
    <ToolExecutionDetailsDialog
      v-if="selected"
      :execution-id="selected"
      @close="selected = null"
    />
  </main>
</template>
