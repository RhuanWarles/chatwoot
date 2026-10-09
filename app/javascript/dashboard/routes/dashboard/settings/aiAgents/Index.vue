<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import { suggestedModelsForProvider } from './models';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { agentPayload, newAgent, validAgent } from './form';

const { t, locale } = useI18n();
const store = useStore();
const agents = ref([]);
const providers = ref([]);
const loading = ref(true);
const busy = ref(false);
const loadError = ref('');
const actionError = ref('');
const editorError = ref('');
const editor = ref(null);
const deletion = ref(null);
const deleting = ref(null);
const draft = ref(newAgent());
const previousProvider = ref(draft.value.provider);
const editingId = ref(null);
const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const canSave = computed(() => validAgent(draft.value));
const providerLabels = computed(() => ({
  openai: t('AI_AGENTS.PROVIDERS.openai'),
  anthropic: t('AI_AGENTS.PROVIDERS.anthropic'),
  gemini: t('AI_AGENTS.PROVIDERS.gemini'),
  openrouter: t('AI_AGENTS.PROVIDERS.openrouter'),
  groq: t('AI_AGENTS.PROVIDERS.groq'),
}));
const providerOptions = computed(() =>
  providers.value.map(value => ({
    value,
    label: providerLabels.value[value],
  }))
);
const modelOptions = computed(() =>
  suggestedModelsForProvider(draft.value.provider).map(value => ({
    value,
    label: value,
  }))
);

const formatUpdatedAt = timestamp => {
  if (!timestamp) return '';
  return new Intl.DateTimeFormat(locale.value?.replace('_', '-') || undefined, {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(timestamp));
};

const normalizeAgent = agent => ({
  ...agent,
  inboxes: Array.isArray(agent?.inboxes) ? agent.inboxes : [],
});

watch(
  () => draft.value.provider,
  provider => {
    if (provider === previousProvider.value) return;
    previousProvider.value = provider;
    const suggestions = suggestedModelsForProvider(provider);
    if (draft.value.model && !suggestions.includes(draft.value.model)) {
      draft.value.model = '';
    }
  }
);

const unavailableInbox = inbox =>
  draft.value.active &&
  agents.value.some(
    agent =>
      agent.id !== editingId.value &&
      agent.active &&
      (agent.inboxes || []).some(item => item.id === inbox.id)
  );

const load = async () => {
  loading.value = true;
  loadError.value = '';
  try {
    const [response, inboxesLoaded] = await Promise.all([
      aiAgentsAPI.get(),
      store.dispatch('inboxes/get'),
    ]);
    if (!inboxesLoaded) {
      loadError.value = t('AI_AGENTS.LOAD_ERROR');
      return;
    }
    agents.value = Array.isArray(response.data.agents)
      ? response.data.agents.map(normalizeAgent)
      : [];
    providers.value = response.data.providers;
  } catch {
    loadError.value = t('AI_AGENTS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
const openEditor = agent => {
  editingId.value = agent?.id ?? null;
  draft.value = agent
    ? agentPayload({
        ...agent,
        description: agent.description ?? '',
        inbox_ids: (agent.inboxes || []).map(inbox => inbox.id),
      })
    : newAgent();
  previousProvider.value = draft.value.provider;
  editorError.value = '';
  editor.value.open();
};
const errorText = error =>
  error.response?.data?.error === 'inbox_conflict'
    ? t('AI_AGENTS.INBOX_CONFLICT')
    : t('AI_AGENTS.SAVE_ERROR');
const save = async () => {
  if (!canSave.value || busy.value) return;
  busy.value = true;
  editorError.value = '';
  try {
    const payload = { ai_agent: agentPayload(draft.value) };
    const response = editingId.value
      ? await aiAgentsAPI.update(editingId.value, payload)
      : await aiAgentsAPI.create(payload);
    agents.value = agents.value.filter(agent => agent.id !== response.data.id);
    agents.value.push(normalizeAgent(response.data));
    editor.value.close();
  } catch (error) {
    editorError.value = errorText(error);
  } finally {
    busy.value = false;
  }
};
const toggle = async agent => {
  if (busy.value) return;
  busy.value = true;
  actionError.value = '';
  try {
    const { data } = await aiAgentsAPI.update(agent.id, {
      ai_agent: { active: !agent.active },
    });
    agents.value = agents.value.map(item =>
      item.id === data.id ? data : item
    );
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
const remove = async () => {
  if (busy.value || !deleting.value) return;
  busy.value = true;
  try {
    await aiAgentsAPI.delete(deleting.value.id);
    agents.value = agents.value.filter(agent => agent.id !== deleting.value.id);
    deletion.value.close();
  } catch {
    actionError.value = t('AI_AGENTS.DELETE_ERROR');
  } finally {
    busy.value = false;
  }
};
onMounted(load);
</script>

<template>
  <main
    class="flex flex-1 flex-col w-full h-full min-w-0 min-h-0 p-6 overflow-auto bg-n-background"
  >
    <header class="flex flex-wrap items-center justify-between gap-4 mb-6">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('AI_AGENTS.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">{{ t('AI_AGENTS.SUBTITLE') }}</p>
      </div>
      <Button
        :label="t('AI_AGENTS.NEW')"
        icon="i-lucide-plus"
        :disabled="loading || !!loadError || busy"
        @click="openEditor()"
      />
    </header>
    <p class="mb-4 text-sm text-n-slate-11">{{ t('AI_AGENTS.CONFIG_ONLY') }}</p>
    <p v-if="loading" role="status" class="text-n-slate-11">
      {{ t('AI_AGENTS.LOADING') }}
    </p>
    <div
      v-else-if="loadError"
      role="alert"
      class="flex items-center gap-3 text-n-ruby-9"
    >
      {{ loadError }}
      <Button :label="t('AI_AGENTS.RETRY')" @click="load" />
    </div>
    <div v-else class="flex flex-col gap-3">
      <p v-if="actionError" role="alert" class="text-sm text-n-ruby-9">
        {{ actionError }}
      </p>
      <p v-if="!agents.length" class="text-n-slate-11">
        {{ t('AI_AGENTS.EMPTY') }}
      </p>
      <article
        v-for="agent in agents"
        :key="agent.id"
        class="flex flex-wrap justify-between gap-4 p-4 rounded-lg bg-n-solid-2"
      >
        <div class="min-w-0">
          <h2 class="font-medium break-words text-n-slate-12">
            {{ agent.name }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ agent.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE') }}
          </p>
          <p class="text-sm break-all text-n-slate-11">
            {{ providerLabels[agent.provider] }} · {{ agent.model }}
          </p>
          <p class="text-sm text-n-slate-11">
            {{ t('AI_AGENTS.INBOXES') }}:
            {{
              (agent.inboxes || []).map(inbox => inbox.name).join(', ') ||
              t('AI_AGENTS.NO_INBOXES')
            }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ t('AI_AGENTS.UPDATED') }}:
            {{ formatUpdatedAt(agent.updated_at) }}
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Button
            variant="ghost"
            :label="t('AI_AGENTS.EDIT')"
            :disabled="busy"
            @click="openEditor(agent)"
          />
          <Button
            variant="ghost"
            :label="
              agent.active ? t('AI_AGENTS.DEACTIVATE') : t('AI_AGENTS.ACTIVATE')
            "
            :disabled="busy"
            @click="toggle(agent)"
          />
          <Button
            variant="ghost"
            color="ruby"
            :label="t('AI_AGENTS.DELETE')"
            :disabled="busy"
            @click="requestDelete(agent)"
          />
        </div>
      </article>
    </div>
    <Dialog
      ref="editor"
      width="2xl"
      overflow-y-auto
      :title="editingId ? t('AI_AGENTS.EDIT') : t('AI_AGENTS.NEW')"
      :is-loading="busy"
      :disable-confirm-button="!canSave || busy"
      :confirm-button-label="t('AI_AGENTS.SAVE')"
      :cancel-button-label="t('AI_AGENTS.CANCEL')"
      @confirm="save"
    >
      <div class="flex flex-col gap-4 max-h-[65vh] overflow-y-auto p-1">
        <p v-if="editorError" role="alert" class="text-sm text-n-ruby-9">
          {{ editorError }}
        </p>
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
        <label class="flex items-center gap-2 text-sm text-n-slate-12"
          ><input v-model="draft.active" type="checkbox" :disabled="busy" />{{
            t('AI_AGENTS.ACTIVE')
          }}</label
        >
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label class="text-sm text-n-slate-12">{{
              t('AI_AGENTS.PROVIDER')
            }}</label
            ><ComboBox
              v-model="draft.provider"
              :options="providerOptions"
              :disabled="busy"
            />
          </div>
          <div class="flex flex-col gap-2">
            <label class="text-sm text-n-slate-12">
              {{ t('AI_AGENTS.MODEL_SUGGESTION') }}
            </label>
            <ComboBox
              v-model="draft.model"
              :options="modelOptions"
              :placeholder="t('AI_AGENTS.MODEL_PLACEHOLDER')"
              :search-placeholder="t('AI_AGENTS.MODEL_SEARCH')"
              :empty-state="t('AI_AGENTS.MODEL_EMPTY')"
              :disabled="busy"
            />
          </div>
          <Input
            v-model="draft.model"
            :label="t('AI_AGENTS.MODEL')"
            :placeholder="t('AI_AGENTS.MODEL_CUSTOM_PLACEHOLDER')"
            :disabled="busy"
          />
          <p class="text-xs text-n-slate-11 sm:col-span-2">
            {{ t('AI_AGENTS.MODEL_HELP') }}
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
            class="w-full p-3 rounded-lg bg-n-solid-2 text-n-slate-12 border border-n-weak focus:border-n-brand"
        /></label>
        <label class="flex flex-col gap-2 text-sm text-n-slate-12"
          >{{ t('AI_AGENTS.PROMPT')
          }}<textarea
            v-model="draft.system_prompt"
            rows="12"
            :disabled="busy"
            class="w-full p-3 rounded-lg resize-y min-h-48 bg-n-solid-2 text-n-slate-12 border border-n-weak focus:border-n-brand"
          />
        </label>
        <fieldset class="flex flex-col gap-2">
          <legend class="mb-2 text-sm text-n-slate-12">
            {{ t('AI_AGENTS.INBOXES') }}
          </legend>
          <p class="text-xs text-n-slate-11">{{ t('AI_AGENTS.INBOX_HELP') }}</p>
          <label
            v-for="inbox in inboxes"
            :key="inbox.id"
            class="flex items-center gap-2 text-sm text-n-slate-12"
            ><input
              v-model="draft.inbox_ids"
              type="checkbox"
              :value="inbox.id"
              :disabled="
                busy ||
                (unavailableInbox(inbox) && !draft.inbox_ids.includes(inbox.id))
              "
            />{{ inbox.name
            }}<span v-if="unavailableInbox(inbox)" class="text-n-ruby-9">{{
              t('AI_AGENTS.OCCUPIED')
            }}</span></label
          >
          <p v-if="!inboxes.length" class="text-sm text-n-slate-11">
            {{ t('AI_AGENTS.NO_INBOXES') }}
          </p>
        </fieldset>
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <input
            v-model="draft.respond_to_groups"
            type="checkbox"
            :disabled="busy"
          />
          {{ t('AI_AGENTS.RESPOND_TO_GROUPS') }}
        </label>
        <p class="text-xs text-n-slate-11">{{ t('AI_AGENTS.GROUP_HELP') }}</p>
        <label class="flex items-center gap-2 text-sm text-n-slate-12"
          ><input
            v-model="draft.handoff_enabled"
            type="checkbox"
            :disabled="busy"
          />{{ t('AI_AGENTS.HANDOFF') }}</label
        >
        <p class="text-xs text-n-slate-11">{{ t('AI_AGENTS.HANDOFF_HELP') }}</p>
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
  </main>
</template>
