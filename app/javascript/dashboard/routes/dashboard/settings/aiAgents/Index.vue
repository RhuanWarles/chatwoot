<script setup>
import { computed, provide, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { breakpointsTailwind, useBreakpoints } from '@vueuse/core';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import voiceAgentsAPI from 'dashboard/api/voiceAgents';
import knowledgeAPI from 'dashboard/api/knowledgeBases';
import { pipelinesAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
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
import AgentCreateDialog from './AgentCreateDialog.vue';
import TextCredentials from './TextCredentials.vue';
import { normalizeAgent } from './form';
import { AGENTS_WORKSPACE } from './workspace';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { currentAccount, accountId } = useAccount();
const isMobile = useBreakpoints(breakpointsTailwind).smaller('md');

const tabs = computed(() =>
  [
    { label: t('AI_HUB.TEXT'), value: 'text' },
    { label: t('AI_HUB.VOICE'), value: 'voice' },
  ].filter(tab => currentAccount.value?.features?.[`${tab.value}_ai`])
);
const activeType = computed(() => {
  const requested = route.query.type === 'voice' ? 'voice' : 'text';
  return (
    tabs.value.find(tab => tab.value === requested)?.value ||
    tabs.value[0]?.value
  );
});

// Newest first. Both detail panels and the redirect rules read this list.
const agents = ref([]);
const textSettings = ref(null);
const voiceMeta = ref({ providers: [], durationRange: [] });
const loading = ref(true);
const loaded = ref(false);
const loadError = ref('');
const paused = ref(false);
const searchQuery = ref('');
const createDialog = ref(null);
const credentialsDialog = ref(null);
let loadRequest = 0;

const selectedId = computed(() => route.params.agentId);
const selectedAgent = computed(() =>
  agents.value.find(agent => String(agent.id) === String(selectedId.value))
);
const platformMode = computed(() => textSettings.value?.mode === 'platform');
const canCreate = computed(() => loaded.value && !loadError.value);
const createLabel = computed(() =>
  activeType.value === 'voice'
    ? t('AI_HUB.CREATE_VOICE')
    : t('AI_AGENTS.CREATE')
);
const emptyTitle = computed(() =>
  activeType.value === 'voice' ? t('AI_HUB.VOICE_EMPTY') : t('AI_AGENTS.EMPTY')
);
const filteredAgents = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase();
  if (!query) return agents.value;
  return agents.value.filter(agent =>
    agent.name?.toLocaleLowerCase().includes(query)
  );
});

const providerLabels = computed(() => ({
  openai: t('AI_AGENTS.PROVIDERS.openai'),
  anthropic: t('AI_AGENTS.PROVIDERS.anthropic'),
  gemini: t('AI_AGENTS.PROVIDERS.gemini'),
  openrouter: t('AI_AGENTS.PROVIDERS.openrouter'),
  groq: t('AI_AGENTS.PROVIDERS.groq'),
}));
const separator = computed(() => t('AI_AGENTS.SEPARATOR'));
const subtitle = agent => {
  if (activeType.value === 'voice') {
    return agent.provider === 'vapi' ? 'Vapi' : agent.provider;
  }
  const notConfigured = t('AI_AGENTS.NOT_CONFIGURED');
  const provider = platformMode.value
    ? textSettings.value?.platform_provider || notConfigured
    : providerLabels.value[agent.provider] || agent.provider;
  const model = platformMode.value
    ? textSettings.value?.platform_model || notConfigured
    : agent.model;
  return `${provider} ${separator.value} ${model}`;
};

const indexLocation = () => ({
  name: 'ai_agents_settings',
  params: { accountId: accountId.value },
  query: { ...route.query, type: activeType.value },
});
const detailLocation = id => ({
  name: 'ai_agent_detail',
  params: { accountId: accountId.value, agentId: id },
  query: { ...route.query, type: activeType.value },
});
const isSelected = agent => String(agent.id) === String(selectedId.value);

const load = async () => {
  const type = activeType.value;
  if (!type) return;
  loadRequest += 1;
  const request = loadRequest;
  loading.value = true;
  loaded.value = false;
  loadError.value = '';
  agents.value = [];
  try {
    if (type === 'voice') {
      const { data } = await voiceAgentsAPI.get();
      if (request !== loadRequest) return;
      agents.value = sortNewestFirst(data.agents || []);
      voiceMeta.value = {
        providers: data.providers || [],
        durationRange: data.duration_range || [],
      };
    } else {
      const { data } = await aiAgentsAPI.get();
      if (request !== loadRequest) return;
      agents.value = sortNewestFirst((data.agents || []).map(normalizeAgent));
      textSettings.value = data.text;
    }
    loaded.value = true;
  } catch {
    if (request === loadRequest) loadError.value = t('AI_AGENTS.LOAD_ERROR');
  } finally {
    if (request === loadRequest) loading.value = false;
  }
};

// Keeps the left panel in sync after a save, create or toggle, without reloading the list.
const upsert = agent => {
  const record = activeType.value === 'voice' ? agent : normalizeAgent(agent);
  agents.value = sortNewestFirst([
    ...agents.value.filter(item => item.id !== record.id),
    record,
  ]);
};

// Opens the next item (or the previous one) in place of the deleted one; the redirect is paused so
// it does not compete with this navigation while the list changes under the current URL.
const removeAgent = async id => {
  const next = nextAfterRemoval(agents.value, id);
  paused.value = true;
  try {
    agents.value = agents.value.filter(item => item.id !== id);
    await router.replace(next ? detailLocation(next.id) : indexLocation());
  } finally {
    paused.value = false;
  }
};

const goToList = () => router.push(indexLocation());

// Inboxes, tools, knowledge bases and pipelines are only needed by the text editor and do not depend
// on the selected agent, so they are fetched once per visit to this screen instead of per item.
const lookups = ref({ tools: [], knowledgeBases: [], pipelines: [] });
let lookupsRequest = null;
const ensureLookups = () => {
  lookupsRequest ||= Promise.all([
    store.dispatch('inboxes/get'),
    aiAgentsAPI.tools(),
    knowledgeAPI.get(),
    pipelinesAPI.get(),
  ])
    .then(([inboxesLoaded, tools, knowledge, pipelines]) => {
      if (!inboxesLoaded) throw new Error('inboxes');
      lookups.value = {
        tools: tools.data.tools || [],
        knowledgeBases: knowledge.data.bases || [],
        pipelines: pipelines.data || [],
      };
    })
    .catch(error => {
      lookupsRequest = null;
      throw error;
    });
  return lookupsRequest;
};

const selectTab = tab =>
  router.push({
    name: 'ai_agents_settings',
    params: { accountId: accountId.value },
    query: { ...route.query, type: tab.value },
  });

const onCreated = agent => {
  upsert(agent);
  router.push(detailLocation(agent.id));
};

watch(
  [activeType, () => route.query.type],
  ([type, requested]) => {
    if (type && requested !== type) {
      router.replace({ query: { ...route.query, type } });
    }
  },
  { immediate: true }
);
watch([activeType, accountId], () => load(), { immediate: true });

useMasterDetailRedirect({
  items: agents,
  loaded,
  selectedId,
  atIndex: computed(() => route.name === 'ai_agents_settings'),
  isMobile,
  paused,
  detailLocation,
  indexLocation,
});

provide(AGENTS_WORKSPACE, {
  type: activeType,
  agents,
  textSettings,
  voiceMeta,
  lookups,
  ensureLookups,
  upsert,
  removeAgent,
  goToList,
});
</script>

<template>
  <div class="flex w-full h-full min-h-0">
    <div
      v-if="!tabs.length"
      class="w-full p-6 text-sm text-n-slate-11 bg-n-surface-1"
    >
      {{ t('AI_HUB.UNAVAILABLE') }}
    </div>
    <MasterDetailLayout v-else :show-detail="Boolean(selectedId)">
      <template #master>
        <div class="flex flex-col gap-3 p-4 border-b border-n-weak">
          <h1 class="flex items-center gap-2 text-heading-3 text-n-slate-12">
            {{ t('AI_AGENTS.TITLE') }}
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
            >
              {{ agents.length }}
            </span>
          </h1>
          <div
            role="tablist"
            :aria-label="t('AI_HUB.TYPE_LABEL')"
            class="flex gap-1 p-1 rounded-xl bg-n-alpha-1"
          >
            <button
              v-for="tab in tabs"
              :key="tab.value"
              type="button"
              role="tab"
              :aria-selected="tab.value === activeType"
              class="flex-1 px-3 py-1.5 text-sm font-medium rounded-lg transition-colors"
              :class="
                tab.value === activeType
                  ? 'bg-n-surface-1 text-n-slate-12 shadow-sm outline outline-1 outline-n-weak'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="selectTab(tab)"
            >
              {{ tab.label }}
            </button>
          </div>
          <Button
            :label="createLabel"
            icon="i-lucide-plus"
            :disabled="!canCreate"
            @click="createDialog.open()"
          />
          <Input
            v-if="agents.length"
            v-model="searchQuery"
            size="sm"
            :placeholder="t('AI_AGENTS.SEARCH')"
            :aria-label="t('AI_AGENTS.SEARCH')"
          />
        </div>
        <ListSkeleton v-if="loading" />
        <DetailState
          v-else-if="loadError"
          is-error
          :title="loadError"
          :action-label="t('AI_AGENTS.RETRY')"
          @action="load"
        />
        <nav
          v-else
          class="flex flex-col flex-1 min-h-0 gap-1 p-3 overflow-y-auto"
          :aria-label="t('AI_AGENTS.LIST_LABEL')"
        >
          <p
            v-if="agents.length && !filteredAgents.length"
            class="p-3 text-sm text-n-slate-11"
          >
            {{ t('AI_AGENTS.NO_SEARCH_RESULTS') }}
          </p>
          <RouterLink
            v-for="agent in filteredAgents"
            :key="agent.id"
            :to="detailLocation(agent.id)"
            class="flex flex-col gap-1 p-3 transition-colors border rounded-xl"
            :class="
              isSelected(agent)
                ? 'bg-n-solid-2 border-n-strong'
                : 'border-transparent hover:bg-n-alpha-1'
            "
            :aria-current="isSelected(agent) ? 'page' : undefined"
          >
            <span class="flex items-center justify-between gap-2">
              <span class="font-semibold truncate text-n-slate-12">{{
                agent.name
              }}</span>
              <span
                class="size-2 rounded-full shrink-0"
                :class="agent.active ? 'bg-n-teal-9' : 'bg-n-slate-9'"
                role="img"
                :aria-label="
                  agent.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE')
                "
              />
            </span>
            <span class="text-sm truncate text-n-slate-11">{{
              subtitle(agent)
            }}</span>
          </RouterLink>
        </nav>
        <footer class="flex flex-col gap-1 p-3 mt-auto border-t border-n-weak">
          <RouterLink
            :to="{ name: 'saas_ai_settings', params: { accountId } }"
            class="flex items-center gap-2 px-3 py-2 text-sm rounded-lg text-n-slate-11 hover:bg-n-alpha-1 hover:text-n-slate-12"
          >
            <span class="i-lucide-gauge size-4" aria-hidden="true" />
            {{ t('AI_HUB.USAGE') }}
          </RouterLink>
          <button
            v-if="activeType === 'text'"
            type="button"
            class="flex items-center gap-2 px-3 py-2 text-sm text-start rounded-lg text-n-slate-11 hover:bg-n-alpha-1 hover:text-n-slate-12"
            @click="credentialsDialog.open()"
          >
            <span class="i-lucide-settings size-4" aria-hidden="true" />
            {{ t('AI_HUB.TEXT_CONNECTION') }}
          </button>
        </footer>
      </template>

      <DetailSkeleton
        v-if="loading || (loaded && agents.length && !selectedAgent)"
      />
      <DetailState
        v-else-if="loaded && !agents.length"
        :title="emptyTitle"
        :description="t('AI_AGENTS.EMPTY_HELP')"
        :action-label="createLabel"
        action-icon="i-lucide-plus"
        @action="createDialog.open()"
      />
      <router-view v-else-if="selectedAgent" v-slot="{ Component }">
        <component :is="Component" :key="selectedId" />
      </router-view>
    </MasterDetailLayout>
    <AgentCreateDialog
      ref="createDialog"
      :type="activeType"
      @created="onCreated"
    />
    <Dialog
      ref="credentialsDialog"
      width="2xl"
      overflow-y-auto
      :title="t('AI_HUB.TEXT_CONNECTION')"
      :show-confirm-button="false"
      :cancel-button-label="t('AI_AGENTS.CLOSE')"
    >
      <TextCredentials open @saved="load" />
    </Dialog>
  </div>
</template>
