<script setup>
import { computed, ref, watch } from 'vue';
import { useIntervalFn } from '@vueuse/core';
import CalendarAPI from 'dashboard/api/crmCalendar';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import AgentsAPI from 'dashboard/api/agents';
import { dealsAPI } from 'dashboard/api/crm';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';

const props = defineProps({ deal: { type: Object, required: true } });
const emit = defineEmits(['changed']);
const { t, locale } = useI18n();
const route = useRoute();
const calendar = ref(null);
const participantEmail = ref('');
const activities = ref([]);
const agents = ref([]);
const error = ref('');
const saving = ref(false);
const editor = ref(null);
const editingId = ref(null);
const linkedGoogle = ref(false);
const draft = ref({});
const { run, isPending: loading } = useAbortableRequest();
const MILLISECONDS_PER_MINUTE = 60000;
const DEFAULT_DURATION_MINUTES = 30;
const SYNC_POLL_INTERVAL_MS = 5000;
const TYPES = ['task', 'call', 'meeting', 'follow_up'];
const typeOptions = computed(() =>
  TYPES.map(value => ({
    value,
    label: t(`CRM.ACTIVITY_TYPE_${value.toUpperCase()}`),
  }))
);
const ownerOptions = computed(() => [
  { value: '', label: t('CRM.UNASSIGNED') },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);
const pending = computed(() =>
  activities.value.filter(
    activity =>
      activity.status === 'pending' ||
      ['pending', 'failed'].includes(activity.sync_status)
  )
);
const date = value =>
  new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
const load = async () => {
  error.value = '';
  try {
    const result = await run(signal =>
      dealsAPI.activities(props.deal.id).get({ signal })
    );
    if (result) {
      const changed = result.data.some(item =>
        activities.value.some(
          previous =>
            previous.id === item.id &&
            previous.sync_status === 'pending' &&
            item.sync_status !== 'pending'
        )
      );
      activities.value = result.data;
      if (changed) emit('changed');
    }
  } catch {
    error.value = t('CRM.ACTIVITY_LOAD_ERROR');
  }
};
const open = async (activity = null) => {
  error.value = '';
  try {
    const results = await Promise.all([AgentsAPI.get(), CalendarAPI.get()]);
    agents.value = results[0].data;
    calendar.value = results[1].data;
    editingId.value = activity?.id || null;
    linkedGoogle.value = activity?.external_provider === 'google';
    participantEmail.value = '';
    let local = '';
    if (activity) {
      const due = new Date(activity.due_at);
      local = new Date(
        due.getTime() - due.getTimezoneOffset() * MILLISECONDS_PER_MINUTE
      ).toISOString();
    }
    const defaultParticipants = props.deal.contact?.email
      ? [props.deal.contact.email]
      : [];
    draft.value = {
      activity_type: activity?.activity_type || 'task',
      title: activity?.title || '',
      date: local.slice(0, 10),
      time: local.slice(11, 16),
      owner_id: activity?.owner_id ?? props.deal.owner_id ?? '',
      description: activity?.description || '',
      duration_minutes: activity?.duration_minutes || DEFAULT_DURATION_MINUTES,
      participants: activity
        ? [...(activity.participants || [])]
        : defaultParticipants,
      create_calendar: activity?.external_provider === 'google',
      create_meet: activity?.create_meet || false,
    };
    editor.value.open();
  } catch {
    error.value = t('CRM.ACTIVITY_LOAD_ERROR');
  }
};
const mutate = async (id, payload) => {
  if (saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const api = dealsAPI.activities(props.deal.id);
    if (id) await api.update(id, { activity: payload });
    else await api.create({ activity: payload });
    editor.value.close();
    await load();
    emit('changed');
  } catch {
    error.value = t('CRM.ACTIVITY_SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
const save = () => {
  if (!draft.value.title.trim() || !draft.value.date || !draft.value.time)
    return;
  mutate(editingId.value, {
    activity_type: draft.value.activity_type,
    title: draft.value.title.trim(),
    description: draft.value.description,
    owner_id: draft.value.owner_id === '' ? null : draft.value.owner_id,
    due_at: new Date(`${draft.value.date}T${draft.value.time}`).toISOString(),
    ...(draft.value.activity_type === 'meeting'
      ? {
          duration_minutes: Number(draft.value.duration_minutes),
          participants: draft.value.participants,
          create_calendar: draft.value.create_calendar,
          create_meet: draft.value.create_meet && draft.value.create_calendar,
        }
      : {}),
  });
};
const retry = async activity => {
  saving.value = true;
  error.value = '';
  try {
    await dealsAPI.retryActivity(props.deal.id, activity.id);
    await load();
  } catch {
    error.value = t('CRM.CALENDAR_SYNC_FAILED');
  } finally {
    saving.value = false;
  }
};
const addParticipant = () => {
  const email = participantEmail.value.trim();
  if (email && !draft.value.participants.includes(email))
    draft.value.participants.push(email);
  participantEmail.value = '';
};
const { pause, resume } = useIntervalFn(load, SYNC_POLL_INTERVAL_MS, {
  immediate: false,
});
watch(
  () => activities.value.some(activity => activity.sync_status === 'pending'),
  isPending => (isPending ? resume() : pause())
);
watch(() => props.deal.id, load, { immediate: true });
</script>

<template>
  <section class="flex flex-col gap-3 p-4 border border-n-weak rounded-xl">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h2 class="mb-0 text-base font-semibold text-n-slate-12">
        {{ t('CRM.UPCOMING_ACTIVITIES') }}
      </h2>
      <Button
        :label="t('CRM.NEW_ACTIVITY')"
        icon="i-lucide-plus"
        :disabled="saving"
        @click="open()"
      />
    </div>
    <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <p v-if="!loading && !pending.length" class="mb-0 text-sm text-n-slate-11">
      {{ t('CRM.NO_ACTIVITIES') }}
    </p>
    <article
      v-for="activity in pending"
      :key="activity.id"
      class="flex flex-wrap items-start justify-between gap-3 p-3 rounded-lg bg-n-alpha-2"
    >
      <div class="min-w-0">
        <p class="mb-1 text-sm font-medium break-words text-n-slate-12">
          {{ activity.title }}
        </p>
        <p class="mb-1 text-sm text-n-slate-11">
          {{ t(`CRM.ACTIVITY_TYPE_${activity.activity_type.toUpperCase()}`) }} ·
          {{ date(activity.due_at) }}
        </p>
        <span
          v-if="new Date(activity.due_at).getTime() < Date.now()"
          class="text-xs text-n-ruby-11"
          >{{ t('CRM.ACTIVITY_OVERDUE') }}</span
        >
        <p class="mb-0 text-xs text-n-slate-11">
          {{ t('CRM.OWNER') }}:
          {{ activity.owner?.name || t('CRM.UNASSIGNED') }}
        </p>
        <p
          v-if="activity.description"
          class="mt-2 mb-0 text-sm whitespace-pre-wrap break-words text-n-slate-12"
        >
          {{ activity.description }}
        </p>
      </div>
      <div class="flex flex-col gap-2">
        <p
          v-if="activity.activity_type === 'meeting'"
          class="mb-0 text-xs text-n-slate-11"
        >
          {{
            t('CRM.MEETING_DURATION_VALUE', {
              minutes: activity.duration_minutes,
            })
          }}
        </p>
        <p
          v-if="activity.sync_status"
          role="status"
          class="mb-0 text-xs"
          :class="
            activity.sync_status === 'failed'
              ? 'text-n-ruby-11'
              : 'text-n-slate-11'
          "
        >
          {{ t(`CRM.CALENDAR_SYNC_${activity.sync_status.toUpperCase()}`) }}
        </p>
        <a
          v-if="activity.meeting_url"
          :href="activity.meeting_url"
          target="_blank"
          rel="noopener noreferrer"
          class="text-sm text-n-brand"
          >{{ t('CRM.MEETING_JOIN') }}</a
        >
        <a
          v-if="activity.google_event_url"
          :href="activity.google_event_url"
          target="_blank"
          rel="noopener noreferrer"
          class="text-sm text-n-brand"
          >{{ t('CRM.CALENDAR_OPEN_EVENT') }}</a
        >
        <Button
          v-if="activity.sync_status === 'failed' && activity.can_sync"
          :label="t('CRM.RETRY')"
          size="sm"
          variant="faded"
          :disabled="saving"
          @click="retry(activity)"
        />
        <p
          v-if="activity.can_sync === false"
          class="mb-0 text-xs text-n-slate-11"
        >
          {{ t('CRM.CALENDAR_OWNER_ONLY') }}
        </p>
        <div v-if="activity.status === 'pending'" class="flex flex-wrap gap-2">
          <Button
            :label="t('CRM.ACTIVITY_COMPLETE')"
            size="sm"
            :disabled="saving || activity.can_sync === false"
            @click="mutate(activity.id, { status: 'completed' })"
          />
          <Button
            :label="t('CRM.EDIT_ACTIVITY')"
            size="sm"
            variant="faded"
            :disabled="saving || activity.can_sync === false"
            @click="open(activity)"
          />
          <Button
            :label="t('CRM.ACTIVITY_CANCEL')"
            size="sm"
            color="ruby"
            variant="ghost"
            :disabled="saving || activity.can_sync === false"
            @click="mutate(activity.id, { status: 'cancelled' })"
          />
        </div>
      </div>
    </article>
    <Dialog
      ref="editor"
      :title="t(editingId ? 'CRM.EDIT_ACTIVITY' : 'CRM.NEW_ACTIVITY')"
      width="2xl"
      :show-confirm-button="false"
      :show-cancel-button="false"
      :overflow-y-auto="true"
    >
      <form class="flex flex-col gap-4" @submit.prevent="save">
        <fieldset :disabled="saving" class="flex flex-col gap-4 min-w-0">
          <div class="flex flex-col gap-2 text-sm text-n-slate-12">
            <span>{{ t('CRM.ACTIVITY_TYPE') }}</span
            ><ComboBox
              v-model="draft.activity_type"
              :options="typeOptions"
              :disabled="linkedGoogle"
            />
          </div>
          <Input
            v-model="draft.title"
            :label="t('CRM.ACTIVITY_TITLE')"
            :maxlength="255"
            required
          />
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Input
              v-model="draft.date"
              type="date"
              :label="t('CRM.ACTIVITY_DATE')"
              required
            />
            <Input
              v-model="draft.time"
              type="time"
              :label="t('CRM.ACTIVITY_TIME')"
              required
            />
          </div>
          <div class="flex flex-col gap-2 text-sm text-n-slate-12">
            <span>{{ t('CRM.OWNER') }}</span
            ><ComboBox
              v-model="draft.owner_id"
              :disabled="draft.create_calendar"
              :options="ownerOptions"
            />
          </div>
          <template v-if="draft.activity_type === 'meeting'">
            <Input
              v-model="draft.duration_minutes"
              type="number"
              :label="t('CRM.MEETING_DURATION')"
              min="1"
              max="1440"
              required
            />
            <div class="flex flex-col gap-2">
              <label
                for="crm-meeting-participant"
                class="text-sm text-n-slate-12"
                >{{ t('CRM.MEETING_PARTICIPANTS') }}</label
              >
              <div class="flex items-end gap-2">
                <Input
                  id="crm-meeting-participant"
                  v-model="participantEmail"
                  type="email"
                  class="flex-1"
                  @keydown.enter.prevent="addParticipant"
                />
                <Button
                  :label="t('CRM.MEETING_ADD_PARTICIPANT')"
                  variant="faded"
                  @click="addParticipant"
                />
              </div>
              <div
                v-for="email in draft.participants"
                :key="email"
                class="flex items-center justify-between gap-2 text-sm text-n-slate-12"
              >
                <span class="break-all">{{ email }}</span
                ><Button
                  :label="t('CRM.MEETING_REMOVE_PARTICIPANT')"
                  size="sm"
                  variant="ghost"
                  @click="
                    draft.participants = draft.participants.filter(
                      item => item !== email
                    )
                  "
                />
              </div>
            </div>
            <label class="flex items-center gap-2 text-sm text-n-slate-12"
              ><input
                v-model="draft.create_calendar"
                type="checkbox"
                :disabled="linkedGoogle || !calendar?.connected"
                @change="
                  draft.create_calendar && (draft.owner_id = calendar.user_id)
                "
              />{{ t('CRM.MEETING_CREATE_CALENDAR') }}</label
            >
            <label class="flex items-center gap-2 text-sm text-n-slate-12"
              ><input
                v-model="draft.create_meet"
                type="checkbox"
                :disabled="!draft.create_calendar"
              />{{ t('CRM.MEETING_CREATE_MEET') }}</label
            >
            <p
              v-if="draft.create_calendar"
              class="mb-0 text-xs text-n-slate-11"
            >
              {{ t('CRM.CALENDAR_OWNER_ONLY') }}
            </p>
            <p
              v-if="draft.create_calendar"
              class="mb-0 text-xs text-n-slate-11"
            >
              {{ t('CRM.MEETING_INVITATION_HINT') }}
            </p>
            <RouterLink
              :to="{
                name: 'settings_integrations_google_calendar',
                params: { accountId: route.params.accountId },
              }"
              class="text-sm text-n-brand"
            >
              {{ t('CRM.CALENDAR_MANAGE') }}
            </RouterLink>
          </template>
          <Input v-model="draft.description" :label="t('CRM.DESCRIPTION')" />
        </fieldset>
        <div class="flex justify-end gap-2">
          <Button
            :label="t('CRM.CANCEL')"
            variant="ghost"
            :disabled="saving"
            @click="editor.close()"
          />
          <Button
            type="submit"
            :label="t(editingId ? 'CRM.SAVE_CHANGES' : 'CRM.CREATE_ACTIVITY')"
            :is-loading="saving"
            :disabled="!draft.title?.trim() || !draft.date || !draft.time"
          />
        </div>
      </form>
    </Dialog>
  </section>
</template>
