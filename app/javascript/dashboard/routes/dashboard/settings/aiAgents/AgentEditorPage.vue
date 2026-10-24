<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import knowledgeAPI from 'dashboard/api/knowledgeBases';
import { pipelinesAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { suggestedModelsForProvider } from './models';
import {
  agentPayload,
  HANDOFF_CONDITIONS_MAX_LENGTH,
  newAgent,
  validAgent,
} from './form';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const loading = ref(true);
const busy = ref(false);
const error = ref('');
const activeTab = ref('general');
const promptExpanded = ref(false);
const connectionSearch = ref({ inboxes: '', tools: '', knowledge: '' });
const agents = ref([]);
const providers = ref([]);
const textSettings = ref(null);
const tools = ref([]);
const knowledgeBases = ref([]);
const pipelines = ref([]);
const draft = ref(newAgent());
const initialDraft = ref('');
const previousProvider = ref(draft.value.provider);

const filterConnections = (items, query) => {
  const normalizedQuery = query.trim().toLocaleLowerCase();
  if (!normalizedQuery) return items;
  return items.filter(item =>
    item.name?.toLocaleLowerCase().includes(normalizedQuery)
  );
};

const selectedNames = (items, ids) =>
  items.filter(item => ids.includes(item.id)).map(item => item.name);

const isEdit = computed(() => Boolean(route.params.agentId));
const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const platformMode = computed(() => textSettings.value?.mode === 'platform');
const platformTextReady = computed(
  () => textSettings.value?.platform_ready === true
);
const effectivePlatformProvider = computed(
  () => textSettings.value?.platform_provider || ''
);
const effectivePlatformModel = computed(
  () => textSettings.value?.platform_model || ''
);
const toolsUnsupported = computed(() =>
  Boolean(
    platformMode.value &&
      effectivePlatformProvider.value &&
      effectivePlatformProvider.value !== 'openai'
  )
);
const canSave = computed(() => validAgent(draft.value));
const isDirty = computed(
  () =>
    Boolean(initialDraft.value) &&
    JSON.stringify(agentPayload(draft.value)) !== initialDraft.value
);
const tabs = computed(() => [
  { value: 'general', label: t('AI_AGENTS.TABS.GENERAL') },
  { value: 'instructions', label: t('AI_AGENTS.TABS.INSTRUCTIONS') },
  { value: 'behavior', label: t('AI_AGENTS.TABS.BEHAVIOR') },
  { value: 'connections', label: t('AI_AGENTS.TABS.CONNECTIONS') },
]);
const providerLabels = computed(() => ({
  openai: t('AI_AGENTS.PROVIDERS.openai'),
  anthropic: t('AI_AGENTS.PROVIDERS.anthropic'),
  gemini: t('AI_AGENTS.PROVIDERS.gemini'),
  openrouter: t('AI_AGENTS.PROVIDERS.openrouter'),
  groq: t('AI_AGENTS.PROVIDERS.groq'),
}));
const providerOptions = computed(() =>
  providers.value.map(value => ({ value, label: providerLabels.value[value] }))
);
const modelOptions = computed(() =>
  suggestedModelsForProvider(draft.value.provider).map(value => ({
    value,
    label: value,
  }))
);
const filteredInboxes = computed(() =>
  filterConnections(inboxes.value, connectionSearch.value.inboxes)
);
const filteredTools = computed(() =>
  filterConnections(tools.value, connectionSearch.value.tools)
);
const filteredKnowledgeBases = computed(() =>
  filterConnections(knowledgeBases.value, connectionSearch.value.knowledge)
);
const selectedInboxNames = computed(() =>
  selectedNames(inboxes.value, draft.value.inbox_ids)
);
const selectedToolNames = computed(() =>
  selectedNames(tools.value, draft.value.tool_ids)
);
const selectedKnowledgeNames = computed(() =>
  selectedNames(knowledgeBases.value, draft.value.knowledge_base_ids)
);

const connectionCount = items => items.length;
const connectionEmptyKey = type =>
  ({
    inboxes: 'AI_AGENTS.NO_INBOXES',
    tools: 'AI_AGENTS.NO_TOOLS',
    knowledge: 'AI_AGENTS.NO_KNOWLEDGE_BASES',
  })[type];
const connectionDescriptionKey = type =>
  ({
    inboxes: 'AI_AGENTS.INBOX_HELP',
    tools: 'AI_AGENTS.TOOLS_HELP',
    knowledge: 'AI_AGENTS.KNOWLEDGE_HELP',
  })[type];
const connectionSearchKey = type =>
  ({
    inboxes: 'AI_AGENTS.SEARCH_INBOXES',
    tools: 'AI_AGENTS.SEARCH_TOOLS',
    knowledge: 'AI_AGENTS.SEARCH_KNOWLEDGE',
  })[type];

const unavailableInbox = inbox =>
  draft.value.active &&
  agents.value.some(
    agent =>
      agent.id !== Number(route.params.agentId) &&
      agent.active &&
      (agent.inboxes || []).some(item => item.id === inbox.id)
  );

watch(
  () => draft.value.provider,
  provider => {
    if (provider === previousProvider.value) return;
    previousProvider.value = provider;
    const suggestions = suggestedModelsForProvider(provider);
    if (draft.value.model && !suggestions.includes(draft.value.model))
      draft.value.model = '';
  }
);

// Inactive pipelines cannot be newly chosen, but the one already selected stays visible.
const pipelineOptions = computed(() =>
  pipelines.value
    .filter(
      pipeline => pipeline.active || pipeline.id === draft.value.crm_pipeline_id
    )
    .map(pipeline => ({
      value: pipeline.id,
      label: pipeline.active
        ? pipeline.name
        : `${pipeline.name} - ${t('AI_AGENTS.CRM_PIPELINE_INACTIVE')}`,
    }))
);

const normalizeAgent = agent => ({
  ...agent,
  handoff_conditions: agent?.handoff_conditions ?? '',
  customer_memory_enabled: agent?.customer_memory_enabled === true,
  audio_enabled: agent?.audio_enabled === true,
  split_response_messages: agent?.split_response_messages !== false,
  inboxes: Array.isArray(agent?.inboxes) ? agent.inboxes : [],
});

const load = async () => {
  try {
    const [
      response,
      inboxesLoaded,
      toolsResponse,
      knowledgeResponse,
      pipelinesResponse,
      agentResponse,
    ] = await Promise.all([
      aiAgentsAPI.get(),
      store.dispatch('inboxes/get'),
      aiAgentsAPI.tools(),
      knowledgeAPI.get(),
      pipelinesAPI.get(),
      isEdit.value
        ? aiAgentsAPI.show(route.params.agentId)
        : Promise.resolve({ data: null }),
    ]);
    if (!inboxesLoaded) throw new Error('inboxes');
    agents.value = (response.data.agents || []).map(normalizeAgent);
    providers.value = response.data.providers || [];
    textSettings.value = response.data.text;
    tools.value = toolsResponse.data.tools || [];
    knowledgeBases.value = knowledgeResponse.data.bases || [];
    pipelines.value = pipelinesResponse.data || [];
    if (agentResponse.data) {
      const agent = normalizeAgent(agentResponse.data);
      draft.value = agentPayload({
        ...agent,
        description: agent.description || '',
        inbox_ids: agent.inboxes.map(inbox => inbox.id),
      });
    }
    if (platformMode.value) {
      draft.value.provider =
        effectivePlatformProvider.value || draft.value.provider;
      draft.value.model = effectivePlatformModel.value || draft.value.model;
    }
    previousProvider.value = draft.value.provider;
    initialDraft.value = JSON.stringify(agentPayload(draft.value));
  } catch {
    error.value = t('AI_AGENTS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};

const save = async () => {
  if (!canSave.value || busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    const payload = { ai_agent: agentPayload(draft.value) };
    if (isEdit.value) await aiAgentsAPI.update(route.params.agentId, payload);
    else await aiAgentsAPI.create(payload);
    window.dispatchEvent(new Event('saas-ai-credit-status-changed'));
    router.push({ name: 'ai_agents_settings', query: { type: 'text' } });
  } catch (saveError) {
    error.value =
      saveError.response?.data?.error === 'inbox_conflict'
        ? t('AI_AGENTS.INBOX_CONFLICT')
        : t('AI_AGENTS.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
};

const cancel = () =>
  router.push({ name: 'ai_agents_settings', query: { type: 'text' } });

onMounted(load);
</script>

<template>
  <main class="flex flex-col w-full max-w-5xl gap-5 mx-auto pb-8">
    <header
      class="sticky top-0 z-10 flex flex-wrap items-center justify-between gap-4 py-4 border-b bg-n-solid-1 border-n-weak"
    >
      <div class="min-w-0">
        <RouterLink
          :to="{ name: 'ai_agents_settings', query: { type: 'text' } }"
          class="text-sm text-n-blue-11 hover:underline"
        >
          {{ t('AI_AGENTS.BACK') }}
        </RouterLink>
        <div class="flex flex-wrap items-center gap-2 mt-2">
          <h1 class="text-xl font-semibold text-n-slate-12">
            {{ isEdit ? t('AI_AGENTS.EDIT') : t('AI_AGENTS.NEW') }}
          </h1>
          <label
            :title="t('AI_AGENTS.ACTIVE_HELP')"
            class="flex items-center gap-2 text-sm text-n-slate-12"
          >
            <Switch v-model="draft.active" :disabled="loading || busy" />
            {{ draft.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE') }}
          </label>
          <span v-if="isDirty" class="text-xs text-n-amber-11">{{
            t('AI_AGENTS.UNSAVED')
          }}</span>
        </div>
        <p class="max-w-2xl text-sm truncate text-n-slate-11">
          {{ draft.description || t('AI_AGENTS.EDITOR_HELP') }}
        </p>
      </div>
      <div class="flex gap-2">
        <Button
          variant="faded"
          :label="t('AI_AGENTS.CANCEL')"
          :disabled="busy"
          @click="cancel"
        />
        <Button
          :label="t('AI_AGENTS.SAVE')"
          :disabled="loading || busy || !canSave"
          @click="save"
        />
      </div>
    </header>

    <p v-if="error" role="alert" class="text-sm text-n-ruby-9">{{ error }}</p>
    <p v-if="loading" role="status" class="text-sm text-n-slate-11">
      {{ t('AI_AGENTS.LOADING') }}
    </p>
    <template v-else>
      <nav
        class="flex gap-1 p-1 overflow-x-auto rounded-lg bg-n-solid-2"
        :aria-label="t('AI_AGENTS.EDITOR_TABS')"
      >
        <button
          v-for="tab in tabs"
          :key="tab.value"
          type="button"
          class="px-4 py-2 text-sm font-medium whitespace-nowrap rounded-md transition-colors"
          :class="
            activeTab === tab.value
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="activeTab = tab.value"
        >
          {{ tab.label }}
        </button>
      </nav>

      <section
        v-if="activeTab === 'general'"
        class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-2"
      >
        <div>
          <h2 class="font-medium text-n-slate-12">
            {{ t('AI_AGENTS.TABS.GENERAL') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ t('AI_AGENTS.SETTINGS_HELP') }}
          </p>
        </div>
        <Input
          v-model="draft.name"
          :label="t('AI_AGENTS.NAME')"
          :disabled="busy"
        />
        <Input
          v-model="draft.description"
          :label="t('AI_AGENTS.DESCRIPTION')"
          :disabled="busy"
        />
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div class="flex flex-col gap-2">
            <label class="text-sm font-medium text-n-slate-12">{{
              t('AI_AGENTS.MODEL')
            }}</label>
            <div
              class="flex flex-wrap items-center gap-2 p-3 rounded-lg bg-n-solid-1"
            >
              <span class="font-medium text-n-slate-12">{{
                providerLabels[draft.provider] || draft.provider
              }}</span
              ><span class="text-n-slate-10">·</span
              ><span class="text-sm text-n-slate-11">{{
                draft.model || t('AI_AGENTS.NOT_CONFIGURED')
              }}</span>
            </div>
            <template v-if="!platformMode">
              <ComboBox
                v-model="draft.provider"
                :options="providerOptions"
                :disabled="busy"
              /><ComboBox
                v-model="draft.model"
                :options="modelOptions"
                :placeholder="t('AI_AGENTS.MODEL_PLACEHOLDER')"
                :disabled="busy"
              /><Input
                v-model="draft.model"
                :placeholder="t('AI_AGENTS.MODEL_CUSTOM_PLACEHOLDER')"
                :disabled="busy"
              />
              <p class="text-xs text-n-slate-11">
                {{ t('AI_AGENTS.MODEL_HELP') }}
              </p>
            </template>
            <p v-else class="text-xs text-n-slate-11">
              {{
                t('AI_AGENTS.PLATFORM_MODEL_HELP', {
                  provider:
                    effectivePlatformProvider || t('AI_AGENTS.NOT_CONFIGURED'),
                  model:
                    effectivePlatformModel || t('AI_AGENTS.NOT_CONFIGURED'),
                })
              }}
            </p>
          </div>
          <label class="flex flex-col gap-2 text-sm text-n-slate-12"
            >{{ t('AI_AGENTS.TEMPERATURE')
            }}<input
              v-model.number="draft.temperature"
              type="number"
              min="0"
              max="1"
              step="0.01"
              :disabled="busy"
              class="w-full p-3 rounded-lg bg-n-solid-1 text-n-slate-12 border border-n-weak focus:border-n-brand"
            /><span class="text-xs text-n-slate-11">{{
              t('AI_AGENTS.TEMPERATURE_HELP')
            }}</span></label
          >
        </div>
        <div
          v-if="platformMode"
          class="flex flex-wrap items-center justify-between gap-2 p-3 text-sm rounded-lg bg-n-solid-1 text-n-slate-11"
        >
          <span>{{
            t('AI_AGENTS.PLATFORM_CREDITS', {
              amount: textSettings?.available_credits ?? 0,
            })
          }}</span
          ><span>{{
            t('AI_AGENTS.PLATFORM_COST', {
              count: textSettings?.credits_per_request ?? 1,
            })
          }}</span
          ><span v-if="!platformTextReady" class="text-n-amber-11">{{
            t('AI_AGENTS.PLATFORM_NOT_READY')
          }}</span>
        </div>
      </section>

      <section
        v-else-if="activeTab === 'instructions'"
        class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2"
      >
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="font-medium text-n-slate-12">
              {{ t('AI_AGENTS.PROMPT_SECTION') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ t('AI_AGENTS.PROMPT_HELP') }}
            </p>
          </div>
          <Button
            variant="faded"
            :label="
              promptExpanded
                ? t('AI_AGENTS.COLLAPSE_EDITOR')
                : t('AI_AGENTS.EXPAND_EDITOR')
            "
            :disabled="busy"
            @click="promptExpanded = !promptExpanded"
          />
        </div>
        <TextArea
          v-model="draft.system_prompt"
          :label="t('AI_AGENTS.PROMPT')"
          :disabled="busy"
          auto-height
          :min-height="promptExpanded ? '32rem' : '20rem'"
          :max-height="promptExpanded ? '42rem' : '30rem'"
          custom-text-area-class="font-mono leading-6"
        />
        <p class="text-xs text-n-slate-11">
          {{ t('AI_AGENTS.PROMPT_FORMAT_HELP') }}
        </p>
      </section>

      <section
        v-else-if="activeTab === 'behavior'"
        class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-2"
      >
        <div>
          <h2 class="font-medium text-n-slate-12">
            {{ t('AI_AGENTS.BEHAVIOR_SECTION') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ t('AI_AGENTS.BEHAVIOR_HELP') }}
          </p>
        </div>
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
          <label class="flex flex-col gap-2 text-sm text-n-slate-12"
            >{{ t('AI_AGENTS.CONTEXT_MESSAGES_LIMIT')
            }}<input
              v-model.number="draft.context_messages_limit"
              type="number"
              min="1"
              max="100"
              step="1"
              :disabled="busy"
              class="w-full p-3 rounded-lg bg-n-solid-1 text-n-slate-12 border border-n-weak focus:border-n-brand"
            /><span class="text-xs text-n-slate-11">{{
              t('AI_AGENTS.CONTEXT_MESSAGES_LIMIT_HELP')
            }}</span></label
          ><label class="flex flex-col gap-2 text-sm text-n-slate-12"
            >{{ t('AI_AGENTS.RESPONSE_DELAY_SECONDS')
            }}<input
              v-model.number="draft.response_delay_seconds"
              type="number"
              min="0"
              max="10"
              step="1"
              :disabled="busy"
              class="w-full p-3 rounded-lg bg-n-solid-1 text-n-slate-12 border border-n-weak focus:border-n-brand"
            /><span class="text-xs text-n-slate-11">{{
              t('AI_AGENTS.RESPONSE_DELAY_SECONDS_HELP')
            }}</span></label
          >
        </div>
        <div class="flex flex-col gap-3 p-4 rounded-lg bg-n-solid-1">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ t('AI_AGENTS.RESPONSE_GROUP') }}
          </h3>
          <label class="flex items-center justify-between gap-3"
            ><span class="text-sm text-n-slate-12"
              >{{ t('AI_AGENTS.SPLIT_RESPONSE_MESSAGES')
              }}<small class="block text-xs text-n-slate-11">{{
                t('AI_AGENTS.SPLIT_RESPONSE_MESSAGES_HELP')
              }}</small></span
            ><Switch
              v-model="draft.split_response_messages"
              :disabled="busy" /></label
          ><label class="flex items-center justify-between gap-3"
            ><span class="text-sm text-n-slate-12"
              >{{ t('AI_AGENTS.RESPOND_TO_GROUPS')
              }}<small class="block text-xs text-n-slate-11">{{
                t('AI_AGENTS.GROUP_HELP')
              }}</small>
            </span>
            <Switch v-model="draft.respond_to_groups" :disabled="busy" />
          </label>
          <label class="flex items-center justify-between gap-3"
            ><span class="text-sm text-n-slate-12"
              >{{ t('AI_AGENTS.AUDIO_ENABLED')
              }}<small class="block text-xs text-n-slate-11">{{
                t('AI_AGENTS.AUDIO_ENABLED_HELP')
              }}</small></span
            ><Switch v-model="draft.audio_enabled" :disabled="busy" />
          </label>
        </div>
        <div class="flex flex-col gap-3 p-4 rounded-lg bg-n-solid-1">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ t('AI_AGENTS.HANDOFF_GROUP') }}
          </h3>
          <label class="flex items-center justify-between gap-3"
            ><span class="text-sm text-n-slate-12"
              >{{ t('AI_AGENTS.HANDOFF')
              }}<small class="block text-xs text-n-slate-11">{{
                t('AI_AGENTS.HANDOFF_HELP')
              }}</small>
            </span>
            <Switch v-model="draft.handoff_enabled" :disabled="busy" />
          </label>
          <TextArea
            v-if="draft.handoff_enabled"
            v-model="draft.handoff_conditions"
            :label="t('AI_AGENTS.HANDOFF_CONDITIONS')"
            :placeholder="t('AI_AGENTS.HANDOFF_CONDITIONS_PLACEHOLDER')"
            :message="t('AI_AGENTS.HANDOFF_CONDITIONS_HELP')"
            :max-length="HANDOFF_CONDITIONS_MAX_LENGTH"
            :disabled="busy"
            show-character-count
            auto-height
            min-height="6rem"
            max-height="14rem"
          />
          <p
            v-if="toolsUnsupported"
            class="p-3 text-xs rounded-lg bg-n-amber-2 text-n-amber-11"
          >
            {{
              t('AI_AGENTS.TOOLS_UNSUPPORTED_PROVIDER', {
                provider: effectivePlatformProvider,
              })
            }}
          </p>
        </div>
        <div class="flex flex-col gap-3 p-4 rounded-lg bg-n-solid-1">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ t('AI_AGENTS.CRM_MEMORY_GROUP') }}
          </h3>
          <p
            v-if="toolsUnsupported"
            class="p-3 text-xs rounded-lg bg-n-amber-2 text-n-amber-11"
          >
            {{
              t('AI_AGENTS.TOOLS_UNSUPPORTED_PROVIDER', {
                provider: effectivePlatformProvider,
              })
            }}
          </p>
          <label class="flex items-center justify-between gap-3"
            ><span class="text-sm text-n-slate-12"
              >{{ t('AI_AGENTS.CRM_STAGE_AUTOMATION')
              }}<small class="block text-xs text-n-slate-11">{{
                t('AI_AGENTS.CRM_STAGE_AUTOMATION_HELP')
              }}</small></span
            ><Switch
              v-model="draft.crm_stage_automation_enabled"
              :disabled="busy"
          /></label>
          <div
            v-if="draft.crm_stage_automation_enabled"
            class="flex flex-col gap-1"
          >
            <p class="mb-0 text-sm text-n-slate-12">
              {{ t('AI_AGENTS.CRM_PIPELINE') }}
            </p>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ t('AI_AGENTS.CRM_PIPELINE_HELP') }}
            </p>
            <ComboBox
              v-model="draft.crm_pipeline_id"
              :options="pipelineOptions"
              :placeholder="t('AI_AGENTS.CRM_PIPELINE_AUTOMATIC')"
              :disabled="busy"
            />
          </div>
          <label class="flex items-center justify-between gap-3"
            ><span class="text-sm text-n-slate-12"
              >{{ t('AI_AGENTS.CUSTOMER_MEMORY')
              }}<small class="block text-xs text-n-slate-11">{{
                t('AI_AGENTS.CUSTOMER_MEMORY_HELP')
              }}</small>
            </span>
            <Switch v-model="draft.customer_memory_enabled" :disabled="busy" />
          </label>
        </div>
      </section>

      <section v-else class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-2">
        <div>
          <h2 class="font-medium text-n-slate-12">
            {{ t('AI_AGENTS.CONNECTIONS_SECTION') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ t('AI_AGENTS.CONNECTIONS_HELP') }}
          </p>
        </div>
        <p class="p-3 text-sm rounded-lg bg-n-solid-1 text-n-slate-11">
          {{ t('AI_AGENTS.CONNECTIONS_NOTICE') }}
        </p>
        <div class="grid grid-cols-1 gap-5 lg:grid-cols-3">
          <fieldset class="flex flex-col gap-3 min-w-0">
            <legend class="font-medium text-sm text-n-slate-12">
              {{ t('AI_AGENTS.INBOXES') }}
              <span class="font-normal text-n-slate-10"
                >({{ draft.inbox_ids.length }})</span
              >
            </legend>
            <p class="text-xs text-n-slate-11">
              {{ t(connectionDescriptionKey('inboxes')) }}
            </p>
            <Input
              v-if="connectionCount(inboxes) > 4"
              v-model="connectionSearch.inboxes"
              size="sm"
              :placeholder="t(connectionSearchKey('inboxes'))"
            />
            <div v-if="selectedInboxNames.length" class="flex flex-wrap gap-1">
              <span
                v-for="name in selectedInboxNames"
                :key="name"
                class="px-2 py-1 text-xs rounded-full bg-n-alpha-2 text-n-slate-11"
                >{{ name }}</span
              >
            </div>
            <div
              v-if="!inboxes.length"
              class="p-3 text-sm rounded-lg bg-n-solid-1 text-n-slate-11"
            >
              {{ t(connectionEmptyKey('inboxes')) }}
            </div>
            <div v-else class="flex flex-col gap-1 overflow-y-auto max-h-72">
              <label
                v-for="inbox in filteredInboxes"
                :key="inbox.id"
                class="flex items-start gap-2 p-2 text-sm rounded-lg text-n-slate-12 hover:bg-n-solid-1"
                ><input
                  v-model="draft.inbox_ids"
                  type="checkbox"
                  :value="inbox.id"
                  :disabled="
                    busy ||
                    (unavailableInbox(inbox) &&
                      !draft.inbox_ids.includes(inbox.id))
                  "
                  class="mt-0.5"
                /><span class="min-w-0"
                  >{{ inbox.name
                  }}<small
                    v-if="unavailableInbox(inbox)"
                    class="block text-xs text-n-ruby-9"
                    >{{ t('AI_AGENTS.OCCUPIED') }}</small
                  ></span
                ></label
              >
              <p v-if="!filteredInboxes.length" class="text-sm text-n-slate-11">
                {{ t('AI_AGENTS.NO_SEARCH_RESULTS') }}
              </p>
            </div>
          </fieldset>
          <fieldset class="flex flex-col gap-3 min-w-0">
            <legend class="font-medium text-sm text-n-slate-12">
              {{ t('AI_AGENTS.ASSIGNED_TOOLS') }}
              <span class="font-normal text-n-slate-10"
                >({{ draft.tool_ids.length }})</span
              >
            </legend>
            <p class="text-xs text-n-slate-11">
              {{ t(connectionDescriptionKey('tools')) }}
            </p>
            <p
              v-if="toolsUnsupported"
              class="p-3 text-xs rounded-lg bg-n-amber-2 text-n-amber-11"
            >
              {{
                t('AI_AGENTS.TOOLS_UNSUPPORTED_PROVIDER', {
                  provider: effectivePlatformProvider,
                })
              }}
            </p>
            <Input
              v-if="connectionCount(tools) > 4"
              v-model="connectionSearch.tools"
              size="sm"
              :placeholder="t(connectionSearchKey('tools'))"
            />
            <div v-if="selectedToolNames.length" class="flex flex-wrap gap-1">
              <span
                v-for="name in selectedToolNames"
                :key="name"
                class="px-2 py-1 text-xs rounded-full bg-n-alpha-2 text-n-slate-11"
                >{{ name }}</span
              >
            </div>
            <div
              v-if="!tools.length"
              class="p-3 text-sm rounded-lg bg-n-solid-1 text-n-slate-11"
            >
              {{ t(connectionEmptyKey('tools')) }}
            </div>
            <div v-else class="flex flex-col gap-1 overflow-y-auto max-h-72">
              <label
                v-for="tool in filteredTools"
                :key="tool.id"
                class="flex items-start gap-2 p-2 text-sm rounded-lg text-n-slate-12 hover:bg-n-solid-1"
                ><input
                  v-model="draft.tool_ids"
                  type="checkbox"
                  :value="tool.id"
                  :disabled="busy"
                  class="mt-0.5"
                /><span class="min-w-0"
                  >{{ tool.name
                  }}<small class="block font-mono text-xs text-n-slate-11">{{
                    tool.slug
                  }}</small
                  ><small
                    v-if="!tool.active"
                    class="block text-xs text-n-slate-11"
                    >{{ t('AI_AGENTS.INACTIVE') }}</small
                  ></span
                ></label
              >
              <p v-if="!filteredTools.length" class="text-sm text-n-slate-11">
                {{ t('AI_AGENTS.NO_SEARCH_RESULTS') }}
              </p>
            </div>
          </fieldset>
          <fieldset class="flex flex-col gap-3 min-w-0">
            <legend class="font-medium text-sm text-n-slate-12">
              {{ t('KNOWLEDGE.TITLE') }}
              <span class="font-normal text-n-slate-10"
                >({{ draft.knowledge_base_ids.length }})</span
              >
            </legend>
            <p class="text-xs text-n-slate-11">
              {{ t(connectionDescriptionKey('knowledge')) }}
            </p>
            <Input
              v-if="connectionCount(knowledgeBases) > 4"
              v-model="connectionSearch.knowledge"
              size="sm"
              :placeholder="t(connectionSearchKey('knowledge'))"
            />
            <div
              v-if="selectedKnowledgeNames.length"
              class="flex flex-wrap gap-1"
            >
              <span
                v-for="name in selectedKnowledgeNames"
                :key="name"
                class="px-2 py-1 text-xs rounded-full bg-n-alpha-2 text-n-slate-11"
                >{{ name }}</span
              >
            </div>
            <div
              v-if="!knowledgeBases.length"
              class="p-3 text-sm rounded-lg bg-n-solid-1 text-n-slate-11"
            >
              {{ t(connectionEmptyKey('knowledge')) }}
            </div>
            <div v-else class="flex flex-col gap-1 overflow-y-auto max-h-72">
              <label
                v-for="base in filteredKnowledgeBases"
                :key="base.id"
                class="flex items-start gap-2 p-2 text-sm rounded-lg text-n-slate-12 hover:bg-n-solid-1"
                ><input
                  v-model="draft.knowledge_base_ids"
                  type="checkbox"
                  :value="base.id"
                  :disabled="busy"
                  class="mt-0.5"
                /><span class="min-w-0"
                  >{{ base.name
                  }}<small
                    v-if="!base.active"
                    class="block text-xs text-n-slate-11"
                    >{{ t('AI_AGENTS.INACTIVE') }}</small
                  ></span
                ></label
              >
              <p
                v-if="!filteredKnowledgeBases.length"
                class="text-sm text-n-slate-11"
              >
                {{ t('AI_AGENTS.NO_SEARCH_RESULTS') }}
              </p>
            </div>
          </fieldset>
        </div>
      </section>
    </template>
  </main>
</template>
