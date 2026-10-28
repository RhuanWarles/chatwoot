<script setup>
import { computed, onActivated, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';
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
const searchQuery = ref('');
const canCreate = computed(
  () => !loading.value && !loadError.value && !busy.value
);
const platformMode = computed(() => textSettings.value?.mode === 'platform');
const effectivePlatformProvider = computed(
  () => textSettings.value?.platform_provider || ''
);
const effectivePlatformModel = computed(
  () => textSettings.value?.platform_model || ''
);
const providerLabels = computed(() => ({
  openai: t('AI_AGENTS.PROVIDERS.openai'),
  anthropic: t('AI_AGENTS.PROVIDERS.anthropic'),
  gemini: t('AI_AGENTS.PROVIDERS.gemini'),
  openrouter: t('AI_AGENTS.PROVIDERS.openrouter'),
  groq: t('AI_AGENTS.PROVIDERS.groq'),
}));
const formatUpdatedAt = timestamp =>
  timestamp
    ? new Intl.DateTimeFormat(locale.value?.replace('_', '-') || undefined, {
        dateStyle: 'short',
        timeStyle: 'short',
      }).format(new Date(timestamp))
    : '';
const normalizeAgent = agent => ({
  ...agent,
  inboxes: Array.isArray(agent?.inboxes) ? agent.inboxes : [],
});
const filteredAgents = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase();
  if (!query) return agents.value;
  return agents.value.filter(agent =>
    agent.name?.toLocaleLowerCase().includes(query)
  );
});

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
const openEditor = agent =>
  router.push({
    name: agent ? 'ai_agent_edit' : 'ai_agent_new',
    params: {
      accountId: accountId.value,
      ...(agent ? { agentId: agent.id } : {}),
    },
    query: { type: 'text' },
  });
const openNew = () => openEditor();
const errorText = error => {
  const code = error.response?.data?.error;
  if (code === 'inbox_conflict') return t('AI_AGENTS.INBOX_CONFLICT');
  if (code === 'text_ai_disabled') return t('AI_AGENTS.TEXT_AI_DISABLED');
  return t('AI_AGENTS.TOGGLE_ERROR');
};
const toggleLabel = agent =>
  agent.active ? t('AI_AGENTS.DEACTIVATE') : t('AI_AGENTS.ACTIVATE');
const toggleAriaLabel = agent =>
  agent.active
    ? t('AI_AGENTS.DEACTIVATE_NAMED', { name: agent.name })
    : t('AI_AGENTS.ACTIVATE_NAMED', { name: agent.name });
const toggle = async agent => {
  if (busy.value) return;
  busy.value = true;
  actionError.value = '';
  const previous = agent.active;
  agent.active = !previous;
  try {
    const { data } = await aiAgentsAPI.update(agent.id, {
      ai_agent: { active: !previous },
    });
    agents.value = agents.value.map(item =>
      item.id === data.id ? normalizeAgent(data) : item
    );
    window.dispatchEvent(new Event('saas-ai-credit-status-changed'));
  } catch (error) {
    agent.active = previous;
    useAlert(errorText(error));
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
const actionMenuItems = computed(() => [
  {
    action: 'memories',
    icon: 'i-lucide-brain',
    label: t('AI_AGENTS.MEMORIES'),
  },
  { action: 'delete', icon: 'i-lucide-trash-2', label: t('AI_AGENTS.DELETE') },
]);
const handleMenuAction = ({ action }, agent, hide) => {
  hide();
  if (action === 'memories') openMemories(agent);
  if (action === 'delete') requestDelete(agent);
};
defineExpose({ openNew, canCreate });
onMounted(load);
onActivated(() => {
  if (!loading.value) load();
});
</script>

<template>
  <section class="flex flex-col min-w-0 gap-5">
    <div
      class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"
    >
      <p class="text-sm text-n-slate-11">{{ t('AI_AGENTS.CONFIG_ONLY') }}</p>
      <Input
        v-if="agents.length"
        v-model="searchQuery"
        size="sm"
        class="w-full md:w-72"
        :placeholder="t('AI_AGENTS.SEARCH')"
        :aria-label="t('AI_AGENTS.SEARCH')"
      />
    </div>
    <p v-if="loading" role="status" class="text-n-slate-11">
      {{ t('AI_AGENTS.LOADING') }}
    </p>
    <div
      v-else-if="loadError"
      role="alert"
      class="flex items-center gap-3 text-n-ruby-9"
    >
      {{ loadError }}<Button :label="t('AI_AGENTS.RETRY')" @click="load" />
    </div>
    <div v-else class="flex flex-col gap-3">
      <p v-if="actionError" role="alert" class="text-sm text-n-ruby-9">
        {{ actionError }}
      </p>
      <div
        v-if="!agents.length"
        class="flex flex-col items-start gap-3 rounded-xl border border-dashed border-n-weak p-6"
      >
        <div>
          <p class="font-medium text-n-slate-12">{{ t('AI_AGENTS.EMPTY') }}</p>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('AI_AGENTS.EMPTY_HELP') }}
          </p>
        </div>
        <Button
          :label="t('AI_AGENTS.NEW')"
          icon="i-lucide-plus"
          @click="openNew"
        />
      </div>
      <div
        v-else-if="!filteredAgents.length"
        class="rounded-xl border border-dashed border-n-weak p-6 text-sm text-n-slate-11"
      >
        {{ t('AI_AGENTS.NO_SEARCH_RESULTS') }}
      </div>
      <article
        v-for="agent in filteredAgents"
        :key="agent.id"
        class="flex flex-col justify-between gap-5 rounded-xl border border-n-weak bg-n-solid-1 p-5 transition-colors hover:border-n-strong lg:flex-row lg:items-start"
      >
        <div class="min-w-0 space-y-2">
          <div class="flex flex-wrap items-center gap-2">
            <h2 class="break-words font-medium text-n-slate-12">
              {{ agent.name }}
            </h2>
            <span
              class="inline-flex items-center gap-1.5 rounded-full bg-n-teal-9/10 px-2 py-0.5 text-xs text-n-teal-11"
              :class="{ 'bg-n-slate-9/10 text-n-slate-11': !agent.active }"
            >
              <span
                class="size-1.5 rounded-full bg-current"
                aria-hidden="true"
              />
              {{
                agent.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE')
              }}
            </span>
          </div>
          <p v-if="agent.description" class="text-sm text-n-slate-11">
            {{ agent.description }}
          </p>
          <p v-if="platformMode" class="text-sm text-n-slate-11">
            {{ t('AI_AGENTS.PLATFORM_MODE') }}
            {{ t('AI_AGENTS.SEPARATOR') }}
            {{ effectivePlatformProvider || t('AI_AGENTS.NOT_CONFIGURED') }}
            {{ t('AI_AGENTS.SEPARATOR') }}
            {{ effectivePlatformModel || t('AI_AGENTS.NOT_CONFIGURED') }}
          </p>
          <p v-else class="text-sm break-all text-n-slate-11">
            {{ providerLabels[agent.provider] }}
            {{ t('AI_AGENTS.SEPARATOR') }}
            {{ agent.model }}
          </p>
          <p class="text-sm text-n-slate-11">
            {{
              agent.inboxes.length
                ? t('AI_AGENTS.INBOX_COUNT', { count: agent.inboxes.length })
                : t('AI_AGENTS.NO_INBOXES')
            }}<span v-if="agent.inboxes.length">
              {{ t('AI_AGENTS.SEPARATOR') }}
              {{ agent.inboxes.map(inbox => inbox.name).join(', ') }}
            </span>
          </p>
          <p
            v-if="agent.active && !agent.inboxes.length"
            class="text-sm text-n-amber-11"
          >
            {{ t('AI_AGENTS.ACTIVE_WITHOUT_INBOX') }}
          </p>
          <p class="text-xs text-n-slate-10">
            {{ t('AI_AGENTS.UPDATED') }}{{ t('AI_AGENTS.COLON') }}
            {{ formatUpdatedAt(agent.updated_at) }}
          </p>
        </div>
        <div class="flex shrink-0 flex-wrap items-center gap-3 lg:justify-end">
          <Switch
            v-tooltip="toggleLabel(agent)"
            :model-value="agent.active"
            :disabled="busy"
            :aria-label="toggleAriaLabel(agent)"
            @update:model-value="toggle(agent)"
          />
          <Button
            variant="ghost"
            :label="t('AI_AGENTS.TEST')"
            :disabled="busy"
            @click="
              router.push({
                name: 'ai_agent_playground',
                params: { accountId, agentId: agent.id },
              })
            "
          />
          <Button
            variant="ghost"
            :label="t('AI_AGENTS.EDIT')"
            :disabled="busy"
            @click="openEditor(agent)"
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
                @action="handleMenuAction($event, agent, hide)"
              />
            </template>
          </Popover>
        </div>
      </article>
    </div>
    <TextCredentials class="mt-6" @saved="load" />
    <Dialog
      ref="memoryDialog"
      width="2xl"
      :title="t('AI_AGENTS.MEMORIES')"
      :cancel-button-label="t('AI_AGENTS.CLOSE')"
    >
      <div class="flex flex-col gap-3 max-h-[65vh] overflow-y-auto">
        <p v-if="memoryError" role="alert" class="text-sm text-n-ruby-9">
          {{ memoryError }}
        </p>
        <p v-if="memoryLoading" class="text-sm text-n-slate-11">
          {{ t('AI_AGENTS.LOADING') }}
        </p>
        <p v-else-if="!memories.length" class="text-sm text-n-slate-11">
          {{ t('AI_AGENTS.NO_MEMORIES') }}
        </p>
        <article
          v-for="memory in memories"
          :key="memory.id"
          class="p-3 rounded-lg bg-n-solid-2"
        >
          <div class="flex items-center justify-between gap-3">
            <strong class="text-sm text-n-slate-12">{{
              memory.contact_name || memory.contact_id
            }}</strong>
            <Button
              variant="ghost"
              color="ruby"
              :label="t('AI_AGENTS.CLEAR_MEMORY')"
              @click="clearMemory(memory)"
            />
          </div>
          <p class="mt-2 text-sm whitespace-pre-wrap text-n-slate-11">
            {{ memory.content }}
          </p>
        </article>
      </div>
    </Dialog>
    <Dialog
      ref="deletion"
      type="alert"
      :title="t('AI_AGENTS.DELETE')"
      :description="t('AI_AGENTS.DELETE_CONFIRM', { name: deleting?.name })"
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
  </section>
</template>
