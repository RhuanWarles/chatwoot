<script setup>
import { computed, inject, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import voiceAgentsAPI from 'dashboard/api/voiceAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';
import CopyIdButton from '../aiShared/CopyIdButton.vue';
import UnsavedChangesDialog from '../aiShared/UnsavedChangesDialog.vue';
import { useUnsavedChangesGuard } from '../aiShared/useUnsavedChangesGuard';
import { validVoiceAgent, voiceAgentPayload } from './voiceForm';
import { AGENTS_WORKSPACE } from './workspace';

const props = defineProps({
  agent: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const workspace = inject(AGENTS_WORKSPACE);

const leaveDialog = ref(null);
const deletion = ref(null);
const busy = ref(false);
const removed = ref(false);
const error = ref('');
const actionError = ref('');

const providers = computed(() => workspace.voiceMeta.value.providers);
const durationRange = computed(() => workspace.voiceMeta.value.durationRange);
const providerOptions = computed(() =>
  providers.value.map(value => ({
    value,
    label: value === 'vapi' ? 'Vapi' : value,
  }))
);

const toDraft = source =>
  voiceAgentPayload({
    ...source,
    description: source.description ?? '',
    assistant_id: source.assistant_id ?? '',
    phone_number_id: source.phone_number_id ?? '',
  });

// Last version saved on the server: what "Discard" goes back to.
const savedAgent = ref(props.agent);
const draft = ref(toDraft(props.agent));
// `active` is saved the moment it is toggled in the header, so it is not an unsaved change.
const snapshot = value => {
  const payload = voiceAgentPayload(value);
  delete payload.active;
  return JSON.stringify(payload);
};
const savedSnapshot = ref(snapshot(draft.value));
const isDirty = computed(
  () => !removed.value && snapshot(draft.value) !== savedSnapshot.value
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

const save = async () => {
  if (!isDirty.value || !canSave.value || busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    const { data } = await voiceAgentsAPI.update(props.agent.id, {
      voice_agent: voiceAgentPayload(draft.value),
    });
    workspace.upsert(data);
    savedAgent.value = data;
    draft.value = toDraft(data);
    savedSnapshot.value = snapshot(draft.value);
    useAlert(t('AI_AGENTS.SAVED'));
  } catch {
    error.value = t('AI_AGENTS.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
};

const discard = () => {
  error.value = '';
  draft.value = toDraft({ ...savedAgent.value, active: draft.value.active });
};

// Activating or deactivating is saved right away, like the toggle of the old list cards.
const toggleActive = async () => {
  if (busy.value) return;
  busy.value = true;
  const previous = draft.value.active;
  draft.value.active = !previous;
  try {
    const { data } = await voiceAgentsAPI.update(props.agent.id, {
      voice_agent: { active: !previous },
    });
    workspace.upsert(data);
    savedAgent.value = data;
  } catch {
    draft.value.active = previous;
    useAlert(t('AI_AGENTS.SAVE_ERROR'));
  } finally {
    busy.value = false;
  }
};

const remove = async () => {
  if (busy.value) return;
  busy.value = true;
  actionError.value = '';
  try {
    await voiceAgentsAPI.delete(props.agent.id);
    removed.value = true;
    deletion.value.close();
    await workspace.removeAgent(props.agent.id);
  } catch {
    actionError.value = t('AI_AGENTS.DELETE_ERROR');
  } finally {
    busy.value = false;
  }
};

const actionMenuItems = computed(() => [
  { action: 'delete', icon: 'i-lucide-trash-2', label: t('AI_AGENTS.DELETE') },
]);
const handleMenuAction = ({ action }, hide) => {
  hide();
  if (action === 'delete') {
    actionError.value = '';
    deletion.value.open();
  }
};

useUnsavedChangesGuard(isDirty, leaveDialog);
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
            {{ draft.description || t('AI_HUB.VOICE_CONFIG_ONLY') }}
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
      <section class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-2">
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
        <div class="flex flex-col gap-3 p-4 rounded-lg bg-n-solid-1">
          <label class="flex items-center justify-between gap-3">
            <span class="text-sm text-n-slate-12">{{
              t('AI_HUB.INBOUND')
            }}</span>
            <Switch v-model="draft.inbound_enabled" :disabled="busy" />
          </label>
          <label class="flex items-center justify-between gap-3">
            <span class="text-sm text-n-slate-12">{{
              t('AI_HUB.OUTBOUND')
            }}</span>
            <Switch v-model="draft.outbound_enabled" :disabled="busy" />
          </label>
        </div>
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
      </section>
    </div>
    <UnsavedChangesDialog ref="leaveDialog" />
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
