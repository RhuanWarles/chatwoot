<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import AgentsAPI from 'dashboard/api/agents';
import { dealsAPI, pipelinesAPI } from 'dashboard/api/crm';
import CrmActivities from '../components/CrmActivities.vue';
import CrmDealCustomFields from '../components/CrmDealCustomFields.vue';
import CrmDealConversations from '../components/CrmDealConversations.vue';
import CrmContactPicker from '../components/CrmContactPicker.vue';
import CrmCurrencyInput from '../components/CrmCurrencyInput.vue';
import { brlFormatter } from '../components/currencyHelpers';
import { formatContactPhone } from '../components/contactHelpers';

const NOTE_MAX_LENGTH = 10000;
const { t, locale } = useI18n();
const route = useRoute();
const deal = ref(null);
const summaryExpanded = ref(true);
const pipelines = ref([]);
const agents = ref([]);
const events = ref([]);
const { run, isPending: loading } = useAbortableRequest();
const error = ref('');
const notFound = ref(false);
const saving = ref(false);
const noteSaving = ref(false);
const editor = ref(null);
const currency = ref(null);
const summaryField = ref(null);
const summaryDraft = ref({});
const summaryCurrency = ref(null);
const summaryLoading = ref(false);
const summaryFields = [
  { key: 'pipeline_id', label: 'CRM.PIPELINES_TITLE' },
  { key: 'pipeline_stage_id', label: 'CRM.STAGE' },
  { key: 'value', label: 'CRM.VALUE' },
  { key: 'owner_id', label: 'CRM.OWNER' },
  { key: 'status', label: 'CRM.STATUS' },
  { key: 'description', label: 'CRM.DESCRIPTION' },
];
const summaryStages = computed(
  () =>
    pipelines.value.find(item => item.id === summaryDraft.value.pipeline_id)
      ?.stages || []
);
const draft = ref({});
const note = ref('');
const editingNote = ref(null);
const noteInput = ref(null);
const deletingNote = ref(null);
const noteDeletionDialog = ref(null);
const tab = ref('history');
const noteEditorOpen = ref(false);
const historyTabs = [
  { value: 'history', label: 'CRM.FILTER_ALL' },
  { value: 'activities', label: 'CRM.ACTIVITIES' },
  { value: 'notes', label: 'CRM.NOTES' },
  { value: 'changes', label: 'CRM.HISTORY_CHANGES' },
];
const isActivityEvent = event =>
  event.event_type.startsWith('activity_') ||
  event.event_type.startsWith('meeting_');
const openNoteEditor = async () => {
  noteEditorOpen.value = true;
  await nextTick();
  noteInput.value?.focus();
};
const page = ref(1);
const hasMore = ref(false);
const {
  run: runHistory,
  abort: abortHistory,
  isPending: historyLoading,
} = useAbortableRequest();
const STATUS_KEYS = {
  open: 'CRM.FILTER_OPEN',
  won: 'CRM.STATUS_WON',
  lost: 'CRM.STATUS_LOST',
};
const statusLabel = status => t(STATUS_KEYS[status]);
const statusOptions = computed(() =>
  Object.keys(STATUS_KEYS).map(value => ({ value, label: statusLabel(value) }))
);
const stages = computed(
  () =>
    pipelines.value.find(item => item.id === draft.value.pipeline_id)?.stages ||
    []
);
const ownerOptions = computed(() => [
  { value: '', label: t('CRM.UNASSIGNED') },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);
const visibleEvents = computed(() =>
  events.value.filter(event => {
    if (tab.value === 'notes') return event.event_type === 'note_created';
    if (tab.value === 'activities') return isActivityEvent(event);
    if (tab.value === 'changes')
      return !isActivityEvent(event) && event.event_type !== 'note_created';
    return true;
  })
);
const money = value =>
  value == null || value === ''
    ? t('CRM.NOT_SET')
    : brlFormatter.format(Number(value));
const date = (value, cancellation = false) =>
  new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    dateStyle: cancellation ? 'short' : 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
const eventTitle = event => t(`CRM.EVENT_${event.event_type.toUpperCase()}`);
const eventChange = event => {
  const metadata = event.metadata;
  if (event.event_type === 'custom_field_changed') {
    const format = value => {
      if (
        value == null ||
        value === '' ||
        (Array.isArray(value) && !value.length)
      )
        return t('CRM.NOT_SET');
      if (Array.isArray(value)) return value.join(', ');
      if (typeof value === 'boolean')
        return value ? t('CRM.CF_YES') : t('CRM.CF_NO');
      if (metadata.field_type === 'currency') return money(value);
      return String(value);
    };
    return (
      metadata.field_name +
      ': ' +
      format(metadata.from) +
      ' \u2192 ' +
      format(metadata.to)
    );
  }
  if (
    event.event_type === 'pipeline_changed' ||
    event.event_type === 'stage_changed' ||
    event.event_type === 'owner_changed'
  )
    return `${metadata.from_name || t('CRM.NOT_SET')} → ${metadata.to_name || t('CRM.NOT_SET')}`;
  if (event.event_type === 'status_changed')
    return `${statusLabel(metadata.from)} → ${statusLabel(metadata.to)}`;
  if (event.event_type === 'value_changed')
    return `${money(metadata.from)} → ${money(metadata.to)}`;
  return '';
};
const loadHistory = async (append = false) => {
  try {
    const result = await runHistory(signal =>
      dealsAPI.events(route.params.dealId, append ? page.value + 1 : 1, {
        signal,
      })
    );
    if (!result) return;
    events.value = append
      ? [...events.value, ...result.data.payload]
      : result.data.payload;
    page.value = append ? page.value + 1 : 1;
    hasMore.value = result.data.meta.has_more;
  } catch {
    error.value = t('CRM.DETAIL_LOAD_ERROR');
  }
};
const summaryValue = key => {
  if (key === 'pipeline_id') return deal.value.pipeline.name;
  if (key === 'pipeline_stage_id') return deal.value.pipeline_stage.name;
  if (key === 'value') return money(deal.value.value);
  if (key === 'owner_id') return deal.value.owner?.name || t('CRM.UNASSIGNED');
  if (key === 'status') return statusLabel(deal.value.status);
  return deal.value.description || t('CRM.NOT_SET');
};
const editSummary = async key => {
  if (saving.value || summaryLoading.value) return;
  summaryLoading.value = true;
  error.value = '';
  try {
    if (['pipeline_id', 'pipeline_stage_id', 'owner_id'].includes(key)) {
      const results = await Promise.all([pipelinesAPI.get(), AgentsAPI.get()]);
      pipelines.value = results[0].data;
      agents.value = results[1].data;
    }
    summaryDraft.value = {
      pipeline_id: deal.value.pipeline_id,
      pipeline_stage_id: deal.value.pipeline_stage_id,
      value: deal.value.value ?? '',
      owner_id: deal.value.owner_id ?? '',
      status: deal.value.status,
      description: deal.value.description || '',
    };
    summaryField.value = key;
  } catch {
    error.value = t('CRM.DETAIL_LOAD_ERROR');
  } finally {
    summaryLoading.value = false;
  }
};
const saveSummary = async () => {
  const key = summaryField.value;
  if (!key || saving.value || summaryCurrency.value?.[0]?.isInvalid) return;
  if (
    key === 'pipeline_stage_id' &&
    !summaryStages.value.some(
      stage => stage.id === summaryDraft.value.pipeline_stage_id
    )
  )
    return;
  let value = summaryDraft.value[key];
  if (['value', 'owner_id'].includes(key) && value === '') value = null;
  const payload = { [key]: value };
  if (key === 'pipeline_id' && value !== deal.value.pipeline_id) {
    const firstStage = [...summaryStages.value].sort(
      (a, b) => a.position - b.position || a.id - b.id
    )[0];
    if (!firstStage) {
      error.value = t('CRM.PIPELINE_NO_STAGES');
      return;
    }
    payload.pipeline_stage_id = firstStage.id;
  }
  const changed = Object.entries(payload).some(
    ([field, next]) => (deal.value[field] ?? null) !== next
  );
  if (!changed) {
    summaryField.value = null;
    return;
  }
  saving.value = true;
  error.value = '';
  try {
    deal.value = (await dealsAPI.update(deal.value.id, { deal: payload })).data;
    summaryField.value = null;
    await loadHistory();
  } catch {
    error.value = t('CRM.DETAIL_SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
const load = async () => {
  editor.value?.close();
  summaryField.value = null;
  abortHistory();
  error.value = '';
  deal.value = null;
  events.value = [];
  note.value = '';
  editingNote.value = null;
  noteDeletionDialog.value?.close();
  notFound.value = false;
  try {
    const result = await run(signal =>
      Promise.all([
        dealsAPI.show(route.params.dealId, { signal }),
        dealsAPI.events(route.params.dealId, 1, { signal }),
      ])
    );
    if (!result) return;
    deal.value = result[0].data;
    events.value = result[1].data.payload;
    page.value = 1;
    hasMore.value = result[1].data.meta.has_more;
  } catch (failure) {
    notFound.value = failure.response?.status === 404;
    error.value = notFound.value
      ? t('CRM.DEAL_NOT_FOUND')
      : t('CRM.DETAIL_LOAD_ERROR');
  }
};
const openEditor = async () => {
  summaryField.value = null;
  error.value = '';
  try {
    const results = await Promise.all([pipelinesAPI.get(), AgentsAPI.get()]);
    pipelines.value = results[0].data;
    agents.value = results[1].data;
    draft.value = {
      name: deal.value.name,
      pipeline_id: deal.value.pipeline_id,
      pipeline_stage_id: deal.value.pipeline_stage_id,
      contact_id: deal.value.contact_id,
      owner_id: deal.value.owner_id ?? '',
      status: deal.value.status,
      value: deal.value.value ?? '',
      description: deal.value.description || '',
    };
    editor.value.open();
  } catch {
    error.value = t('CRM.DETAIL_LOAD_ERROR');
  }
};
const update = async payload => {
  if (saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    deal.value = (await dealsAPI.update(deal.value.id, { deal: payload })).data;
    await loadHistory();
    editor.value.close();
  } catch {
    error.value = t('CRM.DETAIL_SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
const save = () => {
  if (!draft.value.name.trim() || currency.value?.isInvalid) return;
  update({
    ...draft.value,
    value: draft.value.value === '' ? null : draft.value.value,
    owner_id: draft.value.owner_id === '' ? null : draft.value.owner_id,
  });
};
const addNote = async () => {
  if (!note.value.trim() || noteSaving.value) return;
  noteSaving.value = true;
  error.value = '';
  try {
    if (editingNote.value)
      await dealsAPI.updateNote(
        deal.value.id,
        editingNote.value,
        note.value.trim()
      );
    else await dealsAPI.addNote(deal.value.id, note.value.trim());
    editingNote.value = null;
    note.value = '';
    noteEditorOpen.value = false;
    await loadHistory();
  } catch {
    error.value = t('CRM.NOTE_SAVE_ERROR');
  } finally {
    noteSaving.value = false;
  }
};
const editNote = event => {
  editingNote.value = event.id;
  note.value = event.metadata.body;
  openNoteEditor();
};
const removeNote = async () => {
  if (noteSaving.value) return;
  noteSaving.value = true;
  try {
    const deletedId = deletingNote.value;
    await dealsAPI.deleteNote(deal.value.id, deletedId);
    deletingNote.value = null;
    noteDeletionDialog.value.close();
    if (editingNote.value === deletedId) {
      editingNote.value = null;
      note.value = '';
    }
    await loadHistory();
  } catch {
    error.value = t('CRM.NOTE_SAVE_ERROR');
  } finally {
    noteSaving.value = false;
  }
};
watch(() => [route.params.accountId, route.params.dealId], load, {
  immediate: true,
});
</script>

<template>
  <main
    class="flex flex-1 flex-col w-full h-full min-w-0 min-h-0 p-4 md:p-6 overflow-y-auto lg:overflow-hidden bg-n-background"
  >
    <RouterLink
      :to="{ name: 'crm_deals', params: { accountId: route.params.accountId } }"
      class="self-start mb-4 text-sm text-n-brand"
    >
      {{ t('CRM.BACK_TO_KANBAN') }}
    </RouterLink>
    <p v-if="loading" class="text-n-slate-11">{{ t('CRM.LOADING_DEAL') }}</p>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-11">{{ error }}</p>
    <Button
      v-if="!loading && !deal && !notFound"
      :label="t('CRM.RETRY')"
      class="self-start"
      @click="load"
    />
    <Dialog
      ref="noteDeletionDialog"
      :is-loading="noteSaving"
      :disable-confirm-button="noteSaving"
      :title="t('CRM.DELETE_NOTE')"
      :confirm-button-label="t('CRM.DELETE_NOTE')"
      @confirm="removeNote"
      @close="deletingNote = null"
    >
      <p class="text-sm text-n-slate-12">{{ t('CRM.DELETE_NOTE_CONFIRM') }}</p>
    </Dialog>
    <template v-if="deal">
      <header
        class="flex flex-wrap items-start justify-between gap-4 mb-5 shrink-0"
      >
        <div class="min-w-0">
          <h1 class="text-xl font-semibold text-n-slate-12 break-words">
            {{ deal.name }}
          </h1>
          <p class="mb-1 text-sm text-n-slate-11">
            {{ deal.pipeline.name }} &gt; {{ deal.pipeline_stage.name }}
          </p>
          <p class="mb-1 text-sm text-n-slate-11">
            {{ t('CRM.OWNER') }}: {{ deal.owner?.name || t('CRM.UNASSIGNED') }}
          </p>
          <span
            class="inline-flex px-2 py-1 rounded-md text-label-small"
            :class="
              deal.status === 'won'
                ? 'bg-n-teal-3 text-n-teal-11'
                : deal.status === 'lost'
                  ? 'bg-n-ruby-3 text-n-ruby-11'
                  : 'bg-n-blue-3 text-n-blue-11'
            "
            >{{ statusLabel(deal.status) }}</span
          >
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Button
            :label="t('CRM.STATUS_WON')"
            color="teal"
            variant="faded"
            :disabled="saving || deal.status === 'won'"
            @click="update({ status: 'won' })"
          />
          <Button
            :label="t('CRM.STATUS_LOST')"
            color="ruby"
            variant="faded"
            :disabled="saving || deal.status === 'lost'"
            @click="update({ status: 'lost' })"
          />
          <Button
            :label="t('CRM.EDIT_DEAL')"
            :disabled="saving"
            icon="i-lucide-pencil"
            @click="openEditor"
          />
        </div>
      </header>
      <div
        class="flex flex-col lg:flex-row gap-5 min-w-0 lg:flex-1 lg:min-h-0 lg:overflow-hidden"
      >
        <aside
          class="flex flex-col w-full min-w-0 lg:min-h-0 lg:overflow-y-auto lg:overscroll-contain p-4 border border-n-weak rounded-xl lg:w-72 xl:w-80 lg:shrink-0 bg-n-alpha-2"
        >
          <button
            type="button"
            class="flex items-center gap-2 py-1 mb-3 text-start text-sm font-semibold text-n-slate-12"
            :aria-expanded="summaryExpanded"
            aria-controls="deal-summary"
            @click="summaryExpanded = !summaryExpanded"
          >
            <span
              class="size-4 shrink-0"
              :class="
                summaryExpanded
                  ? 'i-lucide-chevron-down'
                  : 'i-lucide-chevron-right'
              "
              aria-hidden="true"
            />
            {{ t('CRM.SIDEBAR_SUMMARY') }}
          </button>
          <div
            v-show="summaryExpanded"
            id="deal-summary"
            class="flex flex-col gap-3 pb-4"
          >
            <div v-if="deal.contact" class="flex flex-col gap-2">
              <RouterLink
                :to="{
                  name: 'contacts_edit',
                  params: {
                    accountId: route.params.accountId,
                    contactId: deal.contact.id,
                  },
                }"
                class="flex items-center gap-3 min-w-0 text-n-brand"
              >
                <Avatar
                  :name="
                    deal.contact.name || t('CRM_CONTACT_PICKER.UNNAMED_CONTACT')
                  "
                  :src="deal.contact.thumbnail || ''"
                  :size="40"
                />
                <span class="break-words">{{
                  deal.contact.name || t('CRM_CONTACT_PICKER.UNNAMED_CONTACT')
                }}</span>
              </RouterLink>
              <a
                v-if="deal.contact.phone_number"
                :href="`tel:${deal.contact.phone_number}`"
                class="text-sm text-n-slate-11 break-words"
                >{{ formatContactPhone(deal.contact.phone_number) }}</a
              >
              <a
                v-if="deal.contact.email"
                :href="`mailto:${deal.contact.email}`"
                class="text-sm text-n-slate-11 break-words"
                >{{ deal.contact.email }}</a
              >
              <p
                v-if="
                  deal.contact.company?.name ||
                  deal.contact.additional_attributes?.company_name
                "
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ t('CRM.COMPANY') }}:
                {{
                  deal.contact.company?.name ||
                  deal.contact.additional_attributes.company_name
                }}
              </p>
              <RouterLink
                :to="{
                  name: 'contacts_edit',
                  params: {
                    accountId: route.params.accountId,
                    contactId: deal.contact.id,
                  },
                }"
                class="text-sm text-n-brand"
              >
                {{ t('CRM.VIEW_CONTACT') }}
              </RouterLink>
            </div>
            <dl class="flex flex-col gap-3 m-0 text-sm">
              <div
                v-for="field in summaryFields"
                :key="field.key"
                class="min-w-0"
              >
                <dt class="text-n-slate-11">{{ t(field.label) }}</dt>
                <dd class="m-0 min-w-0 text-n-slate-12">
                  <form
                    v-if="summaryField === field.key"
                    class="flex flex-col gap-2 mt-1"
                    @submit.prevent="saveSummary"
                    @keydown.esc.stop="!saving && (summaryField = null)"
                  >
                    <fieldset
                      :disabled="saving"
                      class="flex flex-col gap-2 min-w-0"
                    >
                      <ComboBox
                        v-if="field.key === 'pipeline_id'"
                        v-model="summaryDraft.pipeline_id"
                        :options="
                          pipelines.map(item => ({
                            value: item.id,
                            label: item.name,
                          }))
                        "
                        :placeholder="t('CRM.SELECT_PIPELINE')"
                      />
                      <ComboBox
                        v-if="field.key === 'pipeline_stage_id'"
                        v-model="summaryDraft.pipeline_stage_id"
                        :options="
                          summaryStages.map(item => ({
                            value: item.id,
                            label: item.name,
                          }))
                        "
                        :placeholder="t('CRM.STAGE')"
                      />
                      <CrmCurrencyInput
                        v-if="field.key === 'value'"
                        ref="summaryCurrency"
                        v-model="summaryDraft.value"
                      />
                      <ComboBox
                        v-if="field.key === 'owner_id'"
                        v-model="summaryDraft.owner_id"
                        :options="ownerOptions"
                        :placeholder="t('CRM.OWNER')"
                      />
                      <ComboBox
                        v-if="field.key === 'status'"
                        v-model="summaryDraft.status"
                        :options="statusOptions"
                        :placeholder="t('CRM.STATUS')"
                      />
                      <textarea
                        v-if="field.key === 'description'"
                        v-model="summaryDraft.description"
                        :aria-label="t('CRM.DESCRIPTION')"
                        rows="4"
                        class="w-full min-w-0 p-2 rounded-lg border border-n-weak bg-n-background text-sm text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
                      />
                      <div class="flex flex-wrap gap-2">
                        <Button
                          type="submit"
                          :label="t('CRM.SAVE_CHANGES')"
                          size="sm"
                          :is-loading="saving"
                          :disabled="
                            (field.key === 'value' &&
                              summaryCurrency?.[0]?.isInvalid) ||
                            (field.key === 'pipeline_stage_id' &&
                              !summaryStages.some(
                                stage =>
                                  stage.id === summaryDraft.pipeline_stage_id
                              ))
                          "
                        />
                        <Button
                          :label="t('CRM.CANCEL')"
                          size="sm"
                          variant="ghost"
                          :disabled="saving"
                          @click="summaryField = null"
                        />
                      </div>
                    </fieldset>
                  </form>
                  <button
                    v-else
                    type="button"
                    class="group flex items-start justify-between gap-2 w-full min-w-0 py-1 px-2 rounded-md text-start cursor-pointer hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-n-brand"
                    :disabled="saving || summaryLoading"
                    @click="editSummary(field.key)"
                  >
                    <span
                      class="min-w-0 whitespace-pre-wrap [overflow-wrap:anywhere]"
                      :class="field.key === 'description' ? 'line-clamp-3' : ''"
                      >{{ summaryValue(field.key) }}</span
                    >
                    <span
                      class="i-lucide-pencil size-3 shrink-0 mt-1 opacity-0 group-hover:opacity-100 group-focus-visible:opacity-100"
                      aria-hidden="true"
                    />
                  </button>
                </dd>
              </div>
              <div>
                <dt class="text-n-slate-11">{{ t('CRM.CREATED_AT') }}</dt>
                <dd class="m-0 text-n-slate-12">{{ date(deal.created_at) }}</dd>
              </div>
              <div>
                <dt class="text-n-slate-11">{{ t('CRM.UPDATED_AT') }}</dt>
                <dd class="m-0 text-n-slate-12">{{ date(deal.updated_at) }}</dd>
              </div>
            </dl>
          </div>
          <CrmDealCustomFields
            :key="route.params.accountId"
            :deal-id="deal.id"
            :deal="deal"
            @changed="loadHistory()"
          />
        </aside>
        <section
          class="flex flex-1 flex-col gap-4 min-w-0 lg:min-h-0 lg:overflow-y-auto lg:overscroll-contain lg:pe-2"
        >
          <CrmActivities
            :key="`${route.params.accountId}-${deal.id}`"
            :deal="deal"
            @changed="loadHistory()"
          />
          <CrmDealConversations
            :key="route.params.accountId"
            :contact-id="deal.contact?.id || null"
          />
          <div class="flex flex-wrap items-center justify-between gap-3">
            <h2 class="m-0 text-base font-semibold text-n-slate-12">
              {{ t('CRM.HISTORY') }}
            </h2>
            <Button
              :label="t('CRM.ADD_NOTE')"
              icon="i-lucide-plus"
              variant="faded"
              @click="openNoteEditor"
            />
          </div>
          <div
            class="flex flex-wrap gap-2"
            role="group"
            :aria-label="t('CRM.HISTORY')"
          >
            <Button
              v-for="item in historyTabs"
              :key="item.value"
              :label="t(item.label)"
              size="sm"
              :variant="tab === item.value ? 'solid' : 'ghost'"
              :aria-pressed="tab === item.value"
              @click="tab = item.value"
            />
          </div>
          <form
            v-if="noteEditorOpen || editingNote"
            class="flex flex-col gap-2 p-3 border border-n-weak rounded-xl"
            @submit.prevent="addNote"
          >
            <label
              for="deal-note"
              class="text-sm font-medium text-n-slate-12"
              >{{ t('CRM.ADD_NOTE') }}</label
            >
            <textarea
              id="deal-note"
              ref="noteInput"
              v-model="note"
              :disabled="noteSaving"
              :maxlength="NOTE_MAX_LENGTH"
              rows="3"
              class="w-full p-3 rounded-lg border border-n-weak bg-n-background text-sm text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
            />
            <Button
              :label="t('CRM.CANCEL')"
              variant="ghost"
              :disabled="noteSaving"
              @click="
                editingNote = null;
                note = '';
                noteEditorOpen = false;
              "
            />
            <Button
              type="submit"
              :label="t('CRM.SAVE_NOTE')"
              class="self-end"
              :disabled="!note.trim()"
              :is-loading="noteSaving"
            />
          </form>
          <p
            v-if="!historyLoading && !visibleEvents.length"
            class="text-sm text-n-slate-11"
          >
            {{ t('CRM.NO_EVENTS') }}
          </p>
          <ol
            class="flex flex-col p-0 m-0 ms-2 list-none border-s border-n-weak"
          >
            <li
              v-for="event in visibleEvents"
              :key="event.id"
              class="relative min-w-0 ms-4 mb-2 p-3 rounded-lg"
              :class="
                event.event_type === 'note_created' ||
                event.event_type === 'activity_cancelled'
                  ? 'bg-n-alpha-2 border border-n-weak'
                  : ''
              "
            >
              <span
                class="absolute -start-6 top-4 size-3 rounded-full border-2 border-n-background bg-n-slate-8"
                aria-hidden="true"
              />
              <div class="flex flex-wrap items-center justify-between gap-2">
                <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                  {{ eventTitle(event) }}
                </h3>
                <time
                  :datetime="event.created_at"
                  class="text-xs text-n-slate-11"
                  >{{
                    date(
                      event.metadata.cancelled_at || event.created_at,
                      event.event_type === 'activity_cancelled'
                    )
                  }}</time
                >
              </div>
              <p class="mt-1 mb-0 text-xs text-n-slate-11">
                {{
                  event.event_type === 'activity_cancelled'
                    ? t('CRM.ACTIVITY_CANCELLED_BY_VALUE', {
                        name:
                          event.metadata.cancelled_by_name ||
                          event.actor?.name ||
                          t('CRM.SYSTEM_ACTOR'),
                      })
                    : event.actor?.name || t('CRM.SYSTEM_ACTOR')
                }}
              </p>
              <p
                v-if="event.event_type === 'note_created'"
                class="mt-2 mb-0 text-sm whitespace-pre-wrap [overflow-wrap:anywhere] text-n-slate-12"
              >
                {{ event.metadata.body }}
              </p>
              <div
                v-if="event.event_type === 'note_created'"
                class="flex gap-2 mt-2"
              >
                <Button
                  v-if="event.can_edit"
                  :label="t('CRM.EDIT_NOTE')"
                  size="sm"
                  variant="ghost"
                  :disabled="noteSaving"
                  @click="editNote(event)"
                />
                <Button
                  v-if="event.can_delete"
                  :label="t('CRM.DELETE_NOTE')"
                  size="sm"
                  variant="ghost"
                  color="ruby"
                  :disabled="noteSaving"
                  @click="
                    deletingNote = event.id;
                    noteDeletionDialog.open();
                  "
                />
              </div>
              <p
                v-if="
                  event.event_type.startsWith('activity_') ||
                  event.event_type.startsWith('meeting_')
                "
                class="mt-2 mb-0 text-sm text-n-slate-11"
              >
                {{ event.metadata.title }} · {{ date(event.metadata.due_at) }}
              </p>
              <p
                v-if="
                  event.event_type === 'activity_cancelled' &&
                  event.metadata.cancellation_reason
                "
                class="mt-2 mb-0 text-sm whitespace-pre-wrap [overflow-wrap:anywhere] text-n-slate-12"
              >
                {{ t('CRM.ACTIVITY_CANCELLATION_REASON') }}:
                {{ event.metadata.cancellation_reason }}
              </p>
              <a
                v-if="event.metadata.meeting_url"
                :href="event.metadata.meeting_url"
                target="_blank"
                rel="noopener noreferrer"
                class="mt-2 text-sm text-n-brand"
                >{{ t('CRM.MEETING_JOIN') }}</a
              >
              <p
                v-else-if="eventChange(event)"
                class="mt-2 mb-0 min-w-0 text-sm whitespace-pre-wrap [overflow-wrap:anywhere] text-n-slate-11"
              >
                {{ eventChange(event) }}
              </p>
            </li>
          </ol>
          <Button
            v-if="hasMore"
            :label="t('CRM.LOAD_MORE')"
            variant="faded"
            :is-loading="historyLoading"
            class="self-start"
            @click="loadHistory(true)"
          />
        </section>
      </div>
    </template>
    <Dialog
      ref="editor"
      width="3xl"
      overflow-y-auto
      :title="t('CRM.EDIT_DEAL')"
      :confirm-button-label="t('CRM.SAVE_CHANGES')"
      :cancel-button-label="t('CRM.CANCEL')"
      :is-loading="saving"
      :disable-confirm-button="!draft.name?.trim() || currency?.isInvalid"
      @confirm="save"
    >
      <fieldset :disabled="saving" class="flex flex-col gap-4 min-w-0">
        <Input v-model="draft.name" :label="t('CRM.NAME')" />
        <ComboBox
          v-model="draft.pipeline_id"
          :options="
            pipelines.map(item => ({ value: item.id, label: item.name }))
          "
          :placeholder="t('CRM.SELECT_PIPELINE')"
          @update:model-value="draft.pipeline_stage_id = stages[0]?.id || ''"
        />
        <ComboBox
          v-model="draft.pipeline_stage_id"
          :options="stages.map(item => ({ value: item.id, label: item.name }))"
          :placeholder="t('CRM.STAGE')"
        />
        <CrmContactPicker v-model="draft.contact_id" :contact="deal?.contact" />
        <CrmCurrencyInput ref="currency" v-model="draft.value" />
        <ComboBox
          v-model="draft.owner_id"
          :options="ownerOptions"
          :placeholder="t('CRM.OWNER')"
        />
        <ComboBox
          v-model="draft.status"
          :options="statusOptions"
          :placeholder="t('CRM.STATUS')"
        />
        <Input v-model="draft.description" :label="t('CRM.DESCRIPTION')" />
        <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
          {{ error }}
        </p>
      </fieldset>
    </Dialog>
  </main>
</template>
