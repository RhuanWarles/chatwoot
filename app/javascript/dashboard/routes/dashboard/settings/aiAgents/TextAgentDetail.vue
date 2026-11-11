<script setup>
import { computed, inject, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import CopyIdButton from '../aiShared/CopyIdButton.vue';
import DetailSkeleton from '../aiShared/DetailSkeleton.vue';
import UnsavedChangesDialog from '../aiShared/UnsavedChangesDialog.vue';
import { useUnsavedChangesGuard } from '../aiShared/useUnsavedChangesGuard';
import AgentMemoriesDialog from './AgentMemoriesDialog.vue';
import GroupResponseBlacklistField from './GroupResponseBlacklistField.vue';
import {
  agentPayload,
  HANDOFF_CONDITIONS_MAX_LENGTH,
  normalizeAgent,
  validAgent,
} from './form';
import { AGENTS_WORKSPACE } from './workspace';

const props = defineProps({
  agent: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const { accountId } = useAccount();
const workspace = inject(AGENTS_WORKSPACE);

const leaveDialog = ref(null);
const memoriesDialog = ref(null);
const deletion = ref(null);
const loading = ref(true);
const busy = ref(false);
const removed = ref(false);
const error = ref('');
const timezoneError = ref('');
const actionError = ref('');
const activeTab = ref('general');
const promptExpanded = ref(false);
const connectionSearch = ref({ inboxes: '', tools: '', knowledge: '' });

const agents = workspace.agents;
const textSettings = workspace.textSettings;
const tools = computed(() => workspace.lookups.value.tools);
const knowledgeBases = computed(() => workspace.lookups.value.knowledgeBases);
const pipelines = computed(() => workspace.lookups.value.pipelines);
const inboxes = computed(() => store.getters['inboxes/getInboxes']);

const filterConnections = (items, query) => {
  const normalizedQuery = query.trim().toLocaleLowerCase();
  if (!normalizedQuery) return items;
  return items.filter(item =>
    item.name?.toLocaleLowerCase().includes(normalizedQuery)
  );
};

const selectedNames = (items, ids) =>
  items.filter(item => ids.includes(item.id)).map(item => item.name);

const platformMode = computed(() => textSettings.value?.mode === 'platform');
const platformTextReady = computed(
  () => textSettings.value?.platform_ready === true
);
const effectivePlatformProvider = computed(
  () => textSettings.value?.platform_provider || ''
);
const configuredTextProvider = computed(
  () =>
    textSettings.value?.provider || textSettings.value?.platform_provider || ''
);
const configuredTextModel = computed(
  () => textSettings.value?.model || textSettings.value?.platform_model || ''
);
const toolsUnsupported = computed(() =>
  Boolean(
    platformMode.value &&
      effectivePlatformProvider.value &&
      effectivePlatformProvider.value !== 'openai'
  )
);

const buildDraft = source => {
  const record = normalizeAgent(source);
  const next = agentPayload({
    ...record,
    description: record.description || '',
    inbox_ids: record.inboxes.map(inbox => inbox.id),
  });
  next.provider = configuredTextProvider.value || next.provider;
  next.model = configuredTextModel.value || next.model;
  return next;
};

// Last version saved on the server: what "Discard" goes back to.
const savedAgent = ref(props.agent);
const draft = ref(buildDraft(props.agent));
// `active` is saved the moment it is toggled in the header, so it is not an unsaved change.
const snapshot = value => {
  const payload = agentPayload(value);
  delete payload.active;
  return JSON.stringify(payload);
};
const savedSnapshot = ref(snapshot(draft.value));
const isDirty = computed(
  () => !removed.value && snapshot(draft.value) !== savedSnapshot.value
);
const canSave = computed(() => validAgent(draft.value));

const tabs = computed(() => [
  { value: 'general', label: t('AI_AGENTS.TABS.GENERAL') },
  { value: 'instructions', label: t('AI_AGENTS.TABS.INSTRUCTIONS') },
  { value: 'behavior', label: t('AI_AGENTS.TABS.BEHAVIOR') },
  { value: 'connections', label: t('AI_AGENTS.TABS.CONNECTIONS') },
]);
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
      agent.id !== props.agent.id &&
      agent.active &&
      (agent.inboxes || []).some(item => item.id === inbox.id)
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

const syncFromServer = data => {
  workspace.upsert(data);
  savedAgent.value = data;
  window.dispatchEvent(new Event('saas-ai-credit-status-changed'));
};

const save = async () => {
  if (!isDirty.value || !canSave.value || busy.value) return;
  busy.value = true;
  error.value = '';
  timezoneError.value = '';
  try {
    const { data } = await aiAgentsAPI.update(props.agent.id, {
      ai_agent: agentPayload(draft.value),
    });
    syncFromServer(data);
    draft.value = buildDraft(data);
    savedSnapshot.value = snapshot(draft.value);
    useAlert(t('AI_AGENTS.SAVED'));
  } catch (saveError) {
    if (saveError.response?.data?.field === 'timezone') {
      timezoneError.value = t('AI_AGENTS.INVALID_TIMEZONE');
    } else {
      error.value =
        saveError.response?.data?.error === 'inbox_conflict'
          ? t('AI_AGENTS.INBOX_CONFLICT')
          : t('AI_AGENTS.SAVE_ERROR');
    }
  } finally {
    busy.value = false;
  }
};

const discard = () => {
  error.value = '';
  timezoneError.value = '';
  draft.value = buildDraft({
    ...savedAgent.value,
    active: draft.value.active,
  });
};

const toggleErrorText = toggleError => {
  const code = toggleError.response?.data?.error;
  if (code === 'inbox_conflict') return t('AI_AGENTS.INBOX_CONFLICT');
  if (code === 'text_ai_disabled') return t('AI_AGENTS.TEXT_AI_DISABLED');
  return t('AI_AGENTS.TOGGLE_ERROR');
};

// Activating or deactivating is saved right away, like the toggle of the old list cards.
const toggleActive = async () => {
  if (busy.value) return;
  busy.value = true;
  const previous = draft.value.active;
  draft.value.active = !previous;
  try {
    const { data } = await aiAgentsAPI.update(props.agent.id, {
      ai_agent: { active: !previous },
    });
    syncFromServer(data);
  } catch (toggleError) {
    draft.value.active = previous;
    useAlert(toggleErrorText(toggleError));
  } finally {
    busy.value = false;
  }
};

const remove = async () => {
  if (busy.value) return;
  busy.value = true;
  actionError.value = '';
  try {
    await aiAgentsAPI.delete(props.agent.id);
    removed.value = true;
    window.dispatchEvent(new Event('saas-ai-credit-status-changed'));
    deletion.value.close();
    await workspace.removeAgent(props.agent.id);
  } catch {
    actionError.value = t('AI_AGENTS.DELETE_ERROR');
  } finally {
    busy.value = false;
  }
};

const openPlayground = () =>
  router.push({
    name: 'ai_agent_playground',
    params: { accountId: accountId.value, agentId: props.agent.id },
  });

const actionMenuItems = computed(() => [
  {
    action: 'memories',
    icon: 'i-lucide-brain',
    label: t('AI_AGENTS.MEMORIES'),
  },
  { action: 'delete', icon: 'i-lucide-trash-2', label: t('AI_AGENTS.DELETE') },
]);
const handleMenuAction = ({ action }, hide) => {
  hide();
  if (action === 'memories') memoriesDialog.value.open();
  if (action === 'delete') {
    actionError.value = '';
    deletion.value.open();
  }
};

useUnsavedChangesGuard(isDirty, leaveDialog);

onMounted(async () => {
  try {
    await workspace.ensureLookups();
  } catch {
    error.value = t('AI_AGENTS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col w-full">
    <header
      class="sticky top-0 z-10 flex flex-wrap items-center justify-between gap-4 px-6 py-4 border-b bg-n-surface-1 border-n-weak"
    >
      <div class="flex items-start min-w-0 gap-2">
        <Button
          class="md:hidden"
          variant="ghost"
          size="sm"
          icon="i-lucide-arrow-left"
          :aria-label="t('AI_HUB.BACK_TO_LIST')"
          @click="workspace.goToList()"
        />
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
            <h2 class="text-heading-1 text-n-slate-12 break-words">
              {{ draft.name || agent.name }}
            </h2>
            <label
              :title="t('AI_AGENTS.ACTIVE_HELP')"
              class="flex items-center gap-2 text-sm text-n-slate-12"
            >
              <Switch
                :model-value="draft.active"
                :disabled="busy"
                @update:model-value="toggleActive"
              />
              {{
                draft.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE')
              }}
            </label>
            <CopyIdButton :id="agent.id" />
          </div>
          <p class="max-w-2xl text-sm truncate text-n-slate-11">
            {{ draft.description || t('AI_AGENTS.EDITOR_HELP') }}
          </p>
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <span v-if="isDirty" class="text-xs text-n-amber-11">{{
          t('AI_AGENTS.UNSAVED')
        }}</span>
        <Button
          variant="ghost"
          :label="t('AI_HUB.DISCARD')"
          :disabled="!isDirty || busy"
          @click="discard"
        />
        <Button
          variant="faded"
          icon="i-lucide-flask-conical"
          :label="t('AI_AGENTS.TEST')"
          :disabled="busy"
          @click="openPlayground"
        />
        <Button
          :label="t('AI_AGENTS.SAVE')"
          :is-loading="busy"
          :disabled="!isDirty || !canSave || busy"
          @click="save"
        />
        <Popover align="end">
          <Button
            icon="i-lucide-ellipsis-vertical"
            variant="ghost"
            size="sm"
            :disabled="busy"
            :aria-label="t('AI_AGENTS.MORE_ACTIONS')"
          />
          <template #content="{ hide }">
            <DropdownMenu
              class="!relative w-56 max-w-[calc(100vw-2rem)]"
              :menu-items="actionMenuItems"
              @action="handleMenuAction($event, hide)"
            />
          </template>
        </Popover>
      </div>
    </header>

    <div class="flex flex-col gap-5 p-6">
      <p v-if="error" role="alert" class="text-sm text-n-ruby-9">
        {{ error }}
      </p>
      <DetailSkeleton v-if="loading" />
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
          <Input
            v-model="draft.timezone"
            :label="t('AI_AGENTS.TIMEZONE')"
            :disabled="busy"
            @input="timezoneError = ''"
          />
          <p
            class="text-xs"
            :class="timezoneError ? 'text-n-ruby-11' : 'text-n-slate-11'"
          >
            {{ timezoneError || t('AI_AGENTS.TIMEZONE_HELP') }}
          </p>
          <div class="grid grid-cols-1 gap-4">
            <p class="text-xs text-n-slate-11">
              {{ t('AI_AGENTS.TEXT_CONFIGURATION_HELP') }}
            </p>
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
            <GroupResponseBlacklistField
              v-model="draft.group_response_blacklist"
              :disabled="busy"
            />
            <label class="flex items-center justify-between gap-3"
              ><span class="text-sm text-n-slate-12"
                >{{ t('AI_AGENTS.AUDIO_ENABLED')
                }}<small class="block text-xs text-n-slate-11">{{
                  t('AI_AGENTS.AUDIO_ENABLED_HELP')
                }}</small></span
              ><Switch v-model="draft.audio_enabled" :disabled="busy" />
            </label>
            <label class="flex items-center justify-between gap-3"
              ><span class="text-sm text-n-slate-12"
                >{{ t('AI_AGENTS.ATTACHMENT_INTERPRETATION_ENABLED')
                }}<small class="block text-xs text-n-slate-11">{{
                  t('AI_AGENTS.ATTACHMENT_INTERPRETATION_ENABLED_HELP')
                }}</small></span
              ><Switch
                v-model="draft.attachment_interpretation_enabled"
                :disabled="busy"
            /></label>
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
              <Switch
                v-model="draft.customer_memory_enabled"
                :disabled="busy"
              />
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
              <div
                v-if="selectedInboxNames.length"
                class="flex flex-wrap gap-1"
              >
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
                <p
                  v-if="!filteredInboxes.length"
                  class="text-sm text-n-slate-11"
                >
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
    </div>
    <UnsavedChangesDialog ref="leaveDialog" />
    <AgentMemoriesDialog ref="memoriesDialog" :agent="agent" />
    <Dialog
      ref="deletion"
      type="alert"
      :title="t('AI_AGENTS.DELETE')"
      :description="t('AI_AGENTS.DELETE_CONFIRM', { name: agent.name })"
      :is-loading="busy"
      :disable-confirm-button="busy"
      :confirm-button-label="t('AI_AGENTS.DELETE')"
      :cancel-button-label="t('AI_AGENTS.CANCEL')"
      @confirm="remove"
    >
      <p v-if="actionError" role="alert" class="text-sm text-n-ruby-9">
        {{ actionError }}
      </p>
    </Dialog>
  </div>
</template>
