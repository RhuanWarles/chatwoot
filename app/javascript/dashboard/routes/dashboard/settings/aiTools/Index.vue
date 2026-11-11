<script setup>
import { computed, provide, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { breakpointsTailwind, useBreakpoints } from '@vueuse/core';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import aiToolsAPI from 'dashboard/api/aiTools';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useAccount } from 'dashboard/composables/useAccount';
import DetailSkeleton from '../aiShared/DetailSkeleton.vue';
import DetailState from '../aiShared/DetailState.vue';
import ListSkeleton from '../aiShared/ListSkeleton.vue';
import MasterDetailLayout from '../aiShared/MasterDetailLayout.vue';
import {
  nextAfterRemoval,
  sortNewestFirst,
  useMasterDetailRedirect,
} from '../aiShared/masterDetail';
import ToolCreateDialog from './ToolCreateDialog.vue';
import { TOOLS_WORKSPACE } from './workspace';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { accountId } = useAccount();
const isMobile = useBreakpoints(breakpointsTailwind).smaller('md');

// Newest first. The detail panel reads this list and the agents that use each tool.
const tools = ref([]);
const agents = ref([]);
const loading = ref(true);
const loaded = ref(false);
const loadError = ref('');
const paused = ref(false);
const search = ref('');
const status = ref('all');
const createDialog = ref(null);
let loadRequest = 0;

const selectedId = computed(() => route.params.toolId);
const isLogsRoute = computed(() => route.name === 'ai_tool_logs');
const selectedTool = computed(() =>
  tools.value.find(tool => String(tool.id) === String(selectedId.value))
);

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

const indexLocation = () => ({
  name: 'ai_tools_settings',
  params: { accountId: accountId.value },
});
const detailLocation = id => ({
  name: 'ai_tool_detail',
  params: { accountId: accountId.value, toolId: id },
});
const isSelected = tool => String(tool.id) === String(selectedId.value);
const method = tool => tool.configuration?.method || 'GET';

const load = async () => {
  loadRequest += 1;
  const request = loadRequest;
  loading.value = true;
  loaded.value = false;
  loadError.value = '';
  tools.value = [];
  try {
    const [toolsResponse, agentsResponse] = await Promise.all([
      aiToolsAPI.get(),
      aiAgentsAPI.get(),
    ]);
    if (request !== loadRequest) return;
    tools.value = sortNewestFirst(toolsResponse.data.tools || []);
    agents.value = agentsResponse.data.agents || [];
    loaded.value = true;
  } catch {
    if (request === loadRequest) loadError.value = t('AI_TOOLS.LOAD_ERROR');
  } finally {
    if (request === loadRequest) loading.value = false;
  }
};

// Keeps the left panel in sync after a save, create or toggle, without reloading the list.
const upsert = tool => {
  tools.value = sortNewestFirst([
    ...tools.value.filter(item => item.id !== tool.id),
    tool,
  ]);
};

// Opens the next tool (or the previous one) in place of the deleted one; the redirect is paused so it
// does not compete with this navigation while the list changes under the current URL.
const removeTool = async id => {
  const next = nextAfterRemoval(tools.value, id);
  paused.value = true;
  try {
    tools.value = tools.value.filter(item => item.id !== id);
    await router.replace(next ? detailLocation(next.id) : indexLocation());
  } finally {
    paused.value = false;
  }
};

const goToList = () => router.push(indexLocation());
const openLogs = () =>
  router.push({
    name: 'ai_tool_logs',
    params: { accountId: accountId.value },
  });

const onCreated = tool => {
  upsert(tool);
  router.push(detailLocation(tool.id));
};

watch(accountId, () => load(), { immediate: true });

useMasterDetailRedirect({
  items: tools,
  loaded,
  selectedId,
  atIndex: computed(() => route.name === 'ai_tools_settings'),
  isMobile,
  paused,
  detailLocation,
  indexLocation,
});

provide(TOOLS_WORKSPACE, {
  tools,
  agents,
  linkedAgents,
  upsert,
  removeTool,
  goToList,
});
</script>

<template>
  <div class="flex w-full h-full min-h-0">
    <MasterDetailLayout :show-detail="Boolean(selectedId) || isLogsRoute">
      <template #master>
        <div class="flex flex-col gap-3 p-4 border-b border-n-weak">
          <div class="flex items-center justify-between gap-2">
            <h1 class="flex items-center gap-2 text-heading-3 text-n-slate-12">
              {{ t('AI_TOOLS.TITLE') }}
              <span
                class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
              >
                {{ tools.length }}
              </span>
            </h1>
            <Button
              :variant="isLogsRoute ? 'faded' : 'ghost'"
              size="sm"
              icon="i-lucide-scroll-text"
              :label="t('AI_TOOLS.LOGS_TAB')"
              @click="openLogs"
            />
          </div>
          <Button
            :label="t('AI_TOOLS.CREATE')"
            icon="i-lucide-plus"
            :disabled="!loaded || Boolean(loadError)"
            @click="createDialog.open()"
          />
          <template v-if="tools.length">
            <Input
              v-model="search"
              size="sm"
              :placeholder="t('AI_TOOLS.SEARCH_PLACEHOLDER')"
              :aria-label="t('AI_TOOLS.SEARCH')"
            />
            <select
              v-model="status"
              :aria-label="t('AI_TOOLS.STATUS_FILTER')"
              class="h-8 px-3 mb-0 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12"
            >
              <option value="all">{{ t('AI_TOOLS.ALL_STATUS') }}</option>
              <option value="active">{{ t('AI_TOOLS.FILTER_ACTIVE') }}</option>
              <option value="inactive">
                {{ t('AI_TOOLS.FILTER_INACTIVE') }}
              </option>
            </select>
          </template>
        </div>
        <ListSkeleton v-if="loading" />
        <DetailState
          v-else-if="loadError"
          is-error
          :title="loadError"
          :action-label="t('AI_TOOLS.RETRY')"
          @action="load"
        />
        <nav
          v-else
          class="flex flex-col flex-1 min-h-0 gap-1 p-3 overflow-y-auto"
          :aria-label="t('AI_TOOLS.LIST_LABEL')"
        >
          <p
            v-if="tools.length && !filteredTools.length"
            class="p-3 text-sm text-n-slate-11"
          >
            {{ t('AI_TOOLS.EMPTY_FILTERED') }}
          </p>
          <RouterLink
            v-for="tool in filteredTools"
            :key="tool.id"
            :to="detailLocation(tool.id)"
            class="flex flex-col gap-1.5 p-3 transition-colors border rounded-xl"
            :class="
              isSelected(tool)
                ? 'bg-n-solid-2 border-n-strong'
                : 'border-transparent hover:bg-n-alpha-1'
            "
            :aria-current="isSelected(tool) ? 'page' : undefined"
          >
            <span class="flex items-center justify-between gap-2">
              <span class="font-semibold truncate text-n-slate-12">{{
                tool.name
              }}</span>
              <span
                class="size-2 rounded-full shrink-0"
                :class="tool.active ? 'bg-n-teal-9' : 'bg-n-slate-9'"
                role="img"
                :aria-label="
                  tool.active ? t('AI_TOOLS.ACTIVE') : t('AI_TOOLS.INACTIVE')
                "
              />
            </span>
            <span class="flex items-center gap-2">
              <span
                class="px-2 py-0.5 text-xs font-medium rounded bg-n-alpha-2 text-n-slate-11"
                >{{ method(tool) }}</span
              >
              <span class="text-xs truncate text-n-slate-11">{{
                tool.configuration?.url || t('AI_TOOLS.NO_URL')
              }}</span>
            </span>
          </RouterLink>
        </nav>
      </template>

      <router-view v-if="isLogsRoute" />
      <DetailSkeleton
        v-else-if="loading || (loaded && tools.length && !selectedTool)"
      />
      <DetailState
        v-else-if="loaded && !tools.length"
        :title="t('AI_TOOLS.EMPTY')"
        :description="t('AI_TOOLS.EMPTY_HELP')"
        :action-label="t('AI_TOOLS.CREATE')"
        action-icon="i-lucide-plus"
        @action="createDialog.open()"
      />
      <router-view v-else-if="selectedTool" v-slot="{ Component }">
        <component :is="Component" :key="selectedId" />
      </router-view>
    </MasterDetailLayout>
    <ToolCreateDialog ref="createDialog" @created="onCreated" />
  </div>
</template>
