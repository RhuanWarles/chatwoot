<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import voiceAgentsAPI from 'dashboard/api/voiceAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { newVoiceAgent, voiceAgentPayload, validVoiceAgent } from './voiceForm';

const { t } = useI18n();
const agents = ref([]);
const providers = ref([]);
const durationRange = ref([]);
const loading = ref(true);
const busy = ref(false);
const loadError = ref('');
const actionError = ref('');
const editorError = ref('');
const editor = ref(null);
const deletion = ref(null);
const deleting = ref(null);
const editingId = ref(null);
const draft = ref(newVoiceAgent());
const providerLabel = provider => (provider === 'vapi' ? 'Vapi' : provider);
const providerOptions = computed(() =>
  providers.value.map(value => ({
    value,
    label: providerLabel(value),
  }))
);
const canSave = computed(() =>
  validVoiceAgent(draft.value, providers.value, durationRange.value)
);
const maxDuration = computed({
  get: () => draft.value.max_call_duration ?? '',
  set: value => {
    draft.value.max_call_duration = value === '' ? null : Number(value);
  },
});

async function load() {
  loading.value = true;
  loadError.value = '';
  try {
    const { data } = await voiceAgentsAPI.get();
    agents.value = data.agents;
    providers.value = data.providers;
    durationRange.value = data.duration_range;
  } catch {
    loadError.value = t('AI_AGENTS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
}

function openEditor(agent) {
  editingId.value = agent?.id ?? null;
  draft.value = agent
    ? voiceAgentPayload({
        ...agent,
        description: agent.description ?? '',
        assistant_id: agent.assistant_id ?? '',
        phone_number_id: agent.phone_number_id ?? '',
      })
    : { ...newVoiceAgent(), provider: providers.value[0] };
  editorError.value = '';
  editor.value.open();
}

async function save() {
  if (!canSave.value || busy.value) return;
  busy.value = true;
  editorError.value = '';
  try {
    const payload = { voice_agent: voiceAgentPayload(draft.value) };
    const { data } = editingId.value
      ? await voiceAgentsAPI.update(editingId.value, payload)
      : await voiceAgentsAPI.create(payload);
    agents.value = agents.value.filter(agent => agent.id !== data.id);
    agents.value.push(data);
    editor.value.close();
  } catch {
    editorError.value = t('AI_AGENTS.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
}

async function toggle(agent) {
  if (busy.value) return;
  busy.value = true;
  actionError.value = '';
  try {
    const { data } = await voiceAgentsAPI.update(agent.id, {
      voice_agent: { active: !agent.active },
    });
    agents.value = agents.value.map(item =>
      item.id === data.id ? data : item
    );
  } catch {
    actionError.value = t('AI_AGENTS.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
}

function requestDelete(agent) {
  deleting.value = agent;
  actionError.value = '';
  deletion.value.open();
}

async function remove() {
  if (busy.value || !deleting.value) return;
  busy.value = true;
  try {
    await voiceAgentsAPI.delete(deleting.value.id);
    agents.value = agents.value.filter(agent => agent.id !== deleting.value.id);
    deletion.value.close();
  } catch {
    actionError.value = t('AI_AGENTS.DELETE_ERROR');
  } finally {
    busy.value = false;
  }
}
onMounted(load);
</script>

<template>
  <section class="flex flex-col gap-4 min-w-0">
    <header class="flex flex-wrap items-center justify-between gap-4">
      <h2 class="text-heading-3 text-n-slate-12">{{ t('AI_HUB.VOICE') }}</h2>
      <Button
        :label="t('AI_HUB.NEW_VOICE')"
        icon="i-lucide-plus"
        :disabled="loading || !!loadError || busy"
        @click="openEditor()"
      />
    </header>
    <p class="text-sm text-n-slate-11">{{ t('AI_HUB.VOICE_CONFIG_ONLY') }}</p>
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
      <p v-if="!agents.length" class="text-n-slate-11">
        {{ t('AI_HUB.VOICE_EMPTY') }}
      </p>
      <article
        v-for="agent in agents"
        :key="agent.id"
        class="flex flex-wrap justify-between gap-4 p-4 rounded-lg bg-n-solid-2"
      >
        <div class="min-w-0">
          <h3 class="font-medium break-words text-n-slate-12">
            {{ agent.name }}
          </h3>
          <p class="text-sm text-n-slate-11">
            {{ agent.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE') }}
          </p>
          <p class="text-sm text-n-slate-11">
            {{ providerLabel(agent.provider) }}
          </p>
          <p class="text-sm break-all text-n-slate-11">
            {{ t('AI_HUB.PHONE_NUMBER_ID') }}:
            {{ agent.phone_number_id || t('AI_HUB.NOT_CONFIGURED') }}
          </p>
          <p class="text-sm text-n-slate-11">
            {{ t('AI_HUB.INBOUND') }}:
            {{ agent.inbound_enabled ? t('AI_HUB.YES') : t('AI_HUB.NO') }} ·
            {{ t('AI_HUB.OUTBOUND') }}:
            {{ agent.outbound_enabled ? t('AI_HUB.YES') : t('AI_HUB.NO') }}
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
      :title="editingId ? t('AI_HUB.EDIT_VOICE') : t('AI_HUB.NEW_VOICE')"
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
        <p class="text-sm text-n-slate-11">
          {{ t('AI_HUB.VOICE_CONFIG_ONLY') }}
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
        <div class="flex flex-col gap-2">
          <label class="text-sm text-n-slate-12">{{
            t('AI_AGENTS.PROVIDER')
          }}</label>
          <ComboBox
            v-model="draft.provider"
            :options="providerOptions"
            :disabled="busy"
          />
        </div>
        <Input
          v-model="draft.assistant_id"
          :label="t('AI_HUB.ASSISTANT_ID')"
          :disabled="busy"
        />
        <Input
          v-model="draft.phone_number_id"
          :label="t('AI_HUB.PHONE_NUMBER_ID')"
          :message="t('AI_HUB.PHONE_ID_HELP')"
          :disabled="busy"
        />
        <label class="flex items-center gap-2 text-sm text-n-slate-12"
          ><input v-model="draft.active" type="checkbox" :disabled="busy" />{{
            t('AI_AGENTS.ACTIVE')
          }}</label
        >
        <label class="flex items-center gap-2 text-sm text-n-slate-12"
          ><input
            v-model="draft.inbound_enabled"
            type="checkbox"
            :disabled="busy"
          />{{ t('AI_HUB.INBOUND') }}</label
        >
        <label class="flex items-center gap-2 text-sm text-n-slate-12"
          ><input
            v-model="draft.outbound_enabled"
            type="checkbox"
            :disabled="busy"
          />{{ t('AI_HUB.OUTBOUND') }}</label
        >
        <Input
          v-model="maxDuration"
          type="number"
          :min="durationRange[0]"
          :max="durationRange[1]"
          :label="t('AI_HUB.MAX_DURATION')"
          :message="
            t('AI_HUB.DURATION_HELP', {
              min: durationRange[0],
              max: durationRange[1],
            })
          "
          :disabled="busy"
        />
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
