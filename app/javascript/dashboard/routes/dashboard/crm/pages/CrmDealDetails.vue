<script setup>
import { computed, ref, watch } from 'vue';
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
import CrmDealConversations from '../components/CrmDealConversations.vue';
import CrmContactPicker from '../components/CrmContactPicker.vue';
import CrmCurrencyInput from '../components/CrmCurrencyInput.vue';
import { brlFormatter } from '../components/currencyHelpers';
import { formatContactPhone } from '../components/contactHelpers';

const NOTE_MAX_LENGTH = 10000;
const { t, locale } = useI18n();
const route = useRoute();
const deal = ref(null);
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
const draft = ref({});
const note = ref('');
const editingNote = ref(null);
const noteInput = ref(null);
const deletingNote = ref(null);
const noteDeletionDialog = ref(null);
const tab = ref('history');
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
  tab.value === 'notes'
    ? events.value.filter(event => event.event_type === 'note_created')
    : events.value
);
const customFieldDisplay = item => {
  if (item.value == null || item.value === '') return t('CRM.NOT_SET');
  if (item.custom_field?.field_type === 'multiselect') {
    try {
      return JSON.parse(item.value).join(', ');
    } catch {
      return item.value;
    }
  }
  if (item.custom_field?.field_type === 'boolean')
    return item.value === 'true' ? t('CRM.YES') : t('CRM.NO');
  return item.value;
};
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
  if (
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
const load = async () => {
  editor.value?.close();
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
  noteInput.value?.focus();
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
    class="flex flex-1 flex-col w-full h-full min-w-0 min-h-0 p-4 md:p-6 overflow-auto bg-n-background"
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
      <header class="flex flex-wrap items-start justify-between gap-4 mb-5">
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
      <div class="flex flex-col lg:flex-row gap-5 min-w-0">
        <aside
          class="flex flex-col gap-4 p-4 border border-n-weak rounded-xl lg:w-80 lg:shrink-0 bg-n-alpha-2"
        >
          <h2 class="mb-0 font-semibold text-n-slate-12">
            {{ t('CRM.DEAL_INFORMATION') }}
          </h2>
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
          <dl class="flex flex-col gap-3 text-sm">
            <div>
              <dt class="text-n-slate-11">{{ t('CRM.PIPELINES_TITLE') }}</dt>
              <dd class="m-0 text-n-slate-12">{{ deal.pipeline.name }}</dd>
            </div>
            <div>
              <dt class="text-n-slate-11">{{ t('CRM.STAGE') }}</dt>
              <dd class="m-0 text-n-slate-12">
                {{ deal.pipeline_stage.name }}
              </dd>
            </div>
            <div>
              <dt class="text-n-slate-11">{{ t('CRM.VALUE') }}</dt>
              <dd class="m-0 font-medium text-n-slate-12">
                {{ money(deal.value) }}
              </dd>
            </div>
            <div>
              <dt class="text-n-slate-11">{{ t('CRM.OWNER') }}</dt>
              <dd class="m-0 text-n-slate-12">
                {{ deal.owner?.name || t('CRM.UNASSIGNED') }}
              </dd>
            </div>
            <div>
              <dt class="text-n-slate-11">{{ t('CRM.STATUS') }}</dt>
              <dd class="m-0 text-n-slate-12">
                {{ statusLabel(deal.status) }}
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
            <div v-if="deal.description">
              <dt class="text-n-slate-11">{{ t('CRM.DESCRIPTION') }}</dt>
              <dd class="m-0 whitespace-pre-wrap break-words text-n-slate-12">
                {{ deal.description }}
              </dd>
            </div>
          </dl>
          <div
            v-if="deal.custom_field_values?.length"
            class="flex flex-col gap-3 pt-4 mt-4 border-t border-n-weak"
          >
            <h2 class="mb-0 text-sm font-medium text-n-slate-12">
              {{ t('CRM.CUSTOM_FIELDS_TITLE') }}
            </h2>
            <dl class="flex flex-col gap-3 text-sm">
              <div v-for="item in deal.custom_field_values" :key="item.id">
                <dt class="text-n-slate-11">{{ item.custom_field.name }}</dt>
                <dd class="m-0 text-n-slate-12">
                  {{ customFieldDisplay(item) }}
                </dd>
              </div>
            </dl>
          </div>
        </aside>
        <section class="flex flex-1 flex-col gap-4 min-w-0">
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
            <div class="flex gap-2">
              <Button
                :label="t('CRM.HISTORY')"
                :variant="tab === 'history' ? 'solid' : 'faded'"
                @click="tab = 'history'"
              />
              <Button
                :label="t('CRM.NOTES')"
                :variant="tab === 'notes' ? 'solid' : 'faded'"
                @click="tab = 'notes'"
              />
            </div>
            <Button
              :label="t('CRM.ADD_NOTE')"
              icon="i-lucide-plus"
              variant="faded"
              @click="noteInput?.focus()"
            />
          </div>
          <form
            class="flex flex-col gap-2 p-4 border border-n-weak rounded-xl"
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
              v-if="editingNote"
              :label="t('CRM.CANCEL')"
              variant="ghost"
              :disabled="noteSaving"
              @click="
                editingNote = null;
                note = '';
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
          <ol class="flex flex-col gap-3 p-0 m-0 list-none">
            <li
              v-for="event in visibleEvents"
              :key="event.id"
              class="p-4 border border-n-weak rounded-xl bg-n-alpha-2"
            >
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
                class="mt-2 mb-0 text-sm whitespace-pre-wrap break-words text-n-slate-12"
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
                class="mt-2 mb-0 text-sm whitespace-pre-wrap break-words text-n-slate-12"
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
                class="mt-2 mb-0 text-sm text-n-slate-11"
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
