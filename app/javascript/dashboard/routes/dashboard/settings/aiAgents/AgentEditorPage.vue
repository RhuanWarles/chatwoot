<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import knowledgeAPI from 'dashboard/api/knowledgeBases';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { suggestedModelsForProvider } from './models';
import { agentPayload, newAgent, validAgent } from './form';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const loading = ref(true);
const busy = ref(false);
const error = ref('');
const agents = ref([]);
const providers = ref([]);
const textSettings = ref(null);
const tools = ref([]);
const knowledgeBases = ref([]);
const draft = ref(newAgent());
const previousProvider = ref(draft.value.provider);
const isEdit = computed(() => Boolean(route.params.agentId));
const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const platformMode = computed(() => textSettings.value?.mode === 'platform');
const platformTextReady = computed(() => textSettings.value?.platform_ready === true);
const effectivePlatformProvider = computed(() => textSettings.value?.platform_provider || '');
const effectivePlatformModel = computed(() => textSettings.value?.platform_model || '');
const canSave = computed(() => validAgent(draft.value));
const providerLabels = computed(() => ({
  openai: t('AI_AGENTS.PROVIDERS.openai'),
  anthropic: t('AI_AGENTS.PROVIDERS.anthropic'),
  gemini: t('AI_AGENTS.PROVIDERS.gemini'),
  openrouter: t('AI_AGENTS.PROVIDERS.openrouter'),
  groq: t('AI_AGENTS.PROVIDERS.groq'),
}));
const providerOptions = computed(() => providers.value.map(value => ({ value, label: providerLabels.value[value] })));
const modelOptions = computed(() => suggestedModelsForProvider(draft.value.provider).map(value => ({ value, label: value })));

watch(() => draft.value.provider, provider => {
  if (provider === previousProvider.value) return;
  previousProvider.value = provider;
  const suggestions = suggestedModelsForProvider(provider);
  if (draft.value.model && !suggestions.includes(draft.value.model)) draft.value.model = '';
});

const normalizeAgent = agent => ({
  ...agent,
  customer_memory_enabled: agent?.customer_memory_enabled === true,
  split_response_messages: agent?.split_response_messages !== false,
  inboxes: Array.isArray(agent?.inboxes) ? agent.inboxes : [],
});

const unavailableInbox = inbox =>
  draft.value.active && agents.value.some(agent =>
    agent.id !== Number(route.params.agentId) && agent.active &&
    (agent.inboxes || []).some(item => item.id === inbox.id)
  );

const load = async () => {
  try {
    const [response, inboxesLoaded, toolsResponse, knowledgeResponse, agentResponse] = await Promise.all([
      aiAgentsAPI.get(),
      store.dispatch('inboxes/get'),
      aiAgentsAPI.tools(),
      knowledgeAPI.get(),
      isEdit.value ? aiAgentsAPI.show(route.params.agentId) : Promise.resolve({ data: null }),
    ]);
    if (!inboxesLoaded) throw new Error('inboxes');
    agents.value = (response.data.agents || []).map(normalizeAgent);
    providers.value = response.data.providers || [];
    textSettings.value = response.data.text;
    tools.value = toolsResponse.data.tools || [];
    knowledgeBases.value = knowledgeResponse.data.bases || [];
    if (agentResponse.data) {
      const agent = normalizeAgent(agentResponse.data);
      draft.value = agentPayload({ ...agent, description: agent.description || '', inbox_ids: agent.inboxes.map(inbox => inbox.id) });
    }
    if (platformMode.value) {
      draft.value.provider = effectivePlatformProvider.value || draft.value.provider;
      draft.value.model = effectivePlatformModel.value || draft.value.model;
    }
    previousProvider.value = draft.value.provider;
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
    error.value = saveError.response?.data?.error === 'inbox_conflict'
      ? t('AI_AGENTS.INBOX_CONFLICT')
      : t('AI_AGENTS.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
};

const cancel = () => router.push({ name: 'ai_agents_settings', query: { type: 'text' } });

onMounted(load);
</script>

<template>
  <main class="flex flex-col w-full max-w-5xl gap-6 mx-auto pb-8">
    <header class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <RouterLink :to="{ name: 'ai_agents_settings', query: { type: 'text' } }" class="text-sm text-n-blue-11 hover:underline">
          {{ t('AI_AGENTS.BACK') }}
        </RouterLink>
        <h1 class="mt-2 text-xl font-semibold text-n-slate-12">{{ isEdit ? t('AI_AGENTS.EDIT') : t('AI_AGENTS.NEW') }}</h1>
        <p class="text-sm text-n-slate-11">{{ t('AI_AGENTS.EDITOR_HELP') }}</p>
      </div>
      <div class="flex gap-2">
        <Button variant="faded" :label="t('AI_AGENTS.CANCEL')" :disabled="busy" @click="cancel" />
        <Button :label="t('AI_AGENTS.SAVE')" :disabled="loading || busy || !canSave" @click="save" />
      </div>
    </header>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-9">{{ error }}</p>
    <p v-if="loading" role="status" class="text-sm text-n-slate-11">{{ t('AI_AGENTS.LOADING') }}</p>
    <template v-else>
      <section class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2">
        <div><h2 class="font-medium text-n-slate-12">{{ t('AI_AGENTS.SETTINGS_SECTION') }}</h2><p class="text-sm text-n-slate-11">{{ t('AI_AGENTS.SETTINGS_HELP') }}</p></div>
        <Input v-model="draft.name" :label="t('AI_AGENTS.NAME')" :disabled="busy" />
        <Input v-model="draft.description" :label="t('AI_AGENTS.DESCRIPTION')" :disabled="busy" />
        <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12"><span>{{ t('AI_AGENTS.ACTIVE') }}</span><Switch v-model="draft.active" :disabled="busy" /></label>
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div><label class="text-sm text-n-slate-12">{{ t('AI_AGENTS.PROVIDER') }}</label><ComboBox v-model="draft.provider" :options="providerOptions" :disabled="busy || platformMode" /></div>
          <div><label class="text-sm text-n-slate-12">{{ t('AI_AGENTS.MODEL_SUGGESTION') }}</label><ComboBox v-model="draft.model" :options="modelOptions" :placeholder="t('AI_AGENTS.MODEL_PLACEHOLDER')" :disabled="busy || platformMode" /></div>
        </div>
        <Input v-model="draft.model" :label="t('AI_AGENTS.MODEL')" :placeholder="t('AI_AGENTS.MODEL_CUSTOM_PLACEHOLDER')" :disabled="busy || platformMode" />
        <p class="text-xs text-n-slate-11">{{ platformMode ? t('AI_AGENTS.PLATFORM_MODEL_HELP', { provider: effectivePlatformProvider || t('AI_AGENTS.NOT_CONFIGURED'), model: effectivePlatformModel || t('AI_AGENTS.NOT_CONFIGURED') }) : t('AI_AGENTS.MODEL_HELP') }}</p>
        <label class="flex flex-col gap-2 text-sm text-n-slate-12">{{ t('AI_AGENTS.TEMPERATURE') }}<input v-model.number="draft.temperature" type="number" min="0" max="1" step="0.01" :disabled="busy" class="w-full p-3 rounded-lg bg-n-solid-1 text-n-slate-12 border border-n-weak focus:border-n-brand" /></label>
        <div v-if="platformMode" class="p-3 text-sm rounded-lg bg-n-solid-1 text-n-slate-11"><p>{{ t('AI_AGENTS.PLATFORM_CREDITS', { amount: textSettings?.available_credits ?? 0 }) }}</p><p>{{ t('AI_AGENTS.PLATFORM_COST', { count: textSettings?.credits_per_request ?? 1 }) }}</p><p v-if="!platformTextReady" class="mt-1 text-n-amber-11">{{ t('AI_AGENTS.PLATFORM_NOT_READY') }}</p></div>
      </section>
      <section class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2">
        <div><h2 class="font-medium text-n-slate-12">{{ t('AI_AGENTS.PROMPT_SECTION') }}</h2><p class="text-sm text-n-slate-11">{{ t('AI_AGENTS.PROMPT_HELP') }}</p></div>
        <TextArea v-model="draft.system_prompt" :label="t('AI_AGENTS.PROMPT')" :disabled="busy" :auto-height="true" :min-height="'20rem'" />
      </section>
      <section class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2">
        <div><h2 class="font-medium text-n-slate-12">{{ t('AI_AGENTS.BEHAVIOR_SECTION') }}</h2><p class="text-sm text-n-slate-11">{{ t('AI_AGENTS.BEHAVIOR_HELP') }}</p></div>
        <label class="flex flex-col gap-2 text-sm text-n-slate-12">{{ t('AI_AGENTS.CONTEXT_MESSAGES_LIMIT') }}<input v-model.number="draft.context_messages_limit" type="number" min="1" max="100" step="1" :disabled="busy" class="w-full p-3 rounded-lg bg-n-solid-1 text-n-slate-12 border border-n-weak focus:border-n-brand" /><span class="text-xs text-n-slate-11">{{ t('AI_AGENTS.CONTEXT_MESSAGES_LIMIT_HELP') }}</span></label>
        <label class="flex flex-col gap-2 text-sm text-n-slate-12">{{ t('AI_AGENTS.RESPONSE_DELAY_SECONDS') }}<input v-model.number="draft.response_delay_seconds" type="number" min="0" max="10" step="1" :disabled="busy" class="w-full p-3 rounded-lg bg-n-solid-1 text-n-slate-12 border border-n-weak focus:border-n-brand" /><span class="text-xs text-n-slate-11">{{ t('AI_AGENTS.RESPONSE_DELAY_SECONDS_HELP') }}</span></label>
        <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12"><span>{{ t('AI_AGENTS.SPLIT_RESPONSE_MESSAGES') }}<small class="block text-xs text-n-slate-11">{{ t('AI_AGENTS.SPLIT_RESPONSE_MESSAGES_HELP') }}</small></span><Switch v-model="draft.split_response_messages" :disabled="busy" /></label>
        <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12"><span>{{ t('AI_AGENTS.RESPOND_TO_GROUPS') }}<small class="block text-xs text-n-slate-11">{{ t('AI_AGENTS.GROUP_HELP') }}</small></span><Switch v-model="draft.respond_to_groups" :disabled="busy" /></label>
        <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12"><span>{{ t('AI_AGENTS.HANDOFF') }}<small class="block text-xs text-n-slate-11">{{ t('AI_AGENTS.HANDOFF_HELP') }}</small></span><Switch v-model="draft.handoff_enabled" :disabled="busy" /></label>
        <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12"><span>{{ t('AI_AGENTS.CRM_STAGE_AUTOMATION') }}<small class="block text-xs text-n-slate-11">{{ t('AI_AGENTS.CRM_STAGE_AUTOMATION_HELP') }}</small></span><Switch v-model="draft.crm_stage_automation_enabled" :disabled="busy" /></label>
        <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12"><span>{{ t('AI_AGENTS.CUSTOMER_MEMORY') }}<small class="block text-xs text-n-slate-11">{{ t('AI_AGENTS.CUSTOMER_MEMORY_HELP') }}</small></span><Switch v-model="draft.customer_memory_enabled" :disabled="busy" /></label>
      </section>
      <section class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2">
        <div><h2 class="font-medium text-n-slate-12">{{ t('AI_AGENTS.CONNECTIONS_SECTION') }}</h2><p class="text-sm text-n-slate-11">{{ t('AI_AGENTS.CONNECTIONS_HELP') }}</p></div>
        <fieldset class="flex flex-col gap-2"><legend class="font-medium text-sm text-n-slate-12">{{ t('AI_AGENTS.INBOXES') }}</legend><label v-for="inbox in inboxes" :key="inbox.id" class="flex items-center gap-2 text-sm text-n-slate-12"><input v-model="draft.inbox_ids" type="checkbox" :value="inbox.id" :disabled="busy || (unavailableInbox(inbox) && !draft.inbox_ids.includes(inbox.id))" />{{ inbox.name }}<span v-if="unavailableInbox(inbox)" class="text-n-ruby-9">{{ t('AI_AGENTS.OCCUPIED') }}</span></label><p v-if="!inboxes.length" class="text-sm text-n-slate-11">{{ t('AI_AGENTS.NO_INBOXES') }}</p></fieldset>
        <fieldset class="flex flex-col gap-2"><legend class="font-medium text-sm text-n-slate-12">{{ t('AI_AGENTS.ASSIGNED_TOOLS') }}</legend><label v-for="tool in tools" :key="tool.id" class="flex items-center gap-2 text-sm text-n-slate-12"><input v-model="draft.tool_ids" type="checkbox" :value="tool.id" :disabled="busy" />{{ tool.name }}<span v-if="!tool.active" class="text-xs text-n-slate-11">({{ t('AI_AGENTS.INACTIVE') }})</span></label></fieldset>
        <fieldset class="flex flex-col gap-2"><legend class="font-medium text-sm text-n-slate-12">{{ t('KNOWLEDGE.TITLE') }}</legend><p class="text-xs text-n-slate-11">{{ t('KNOWLEDGE.AGENT_HELP') }}</p><label v-for="base in knowledgeBases" :key="base.id" class="flex items-center gap-2 text-sm text-n-slate-12"><input v-model="draft.knowledge_base_ids" type="checkbox" :value="base.id" :disabled="busy" />{{ base.name }}<span v-if="!base.active" class="text-xs text-n-slate-11">({{ t('KNOWLEDGE.INACTIVE') }})</span></label></fieldset>
      </section>
    </template>
  </main>
</template>
