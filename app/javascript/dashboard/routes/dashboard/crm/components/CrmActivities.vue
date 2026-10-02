<script setup>
import { computed, ref, watch } from 'vue';
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
const activities = ref([]);
const agents = ref([]);
const error = ref('');
const saving = ref(false);
const editor = ref(null);
const editingId = ref(null);
const draft = ref({});
const { run, isPending: loading } = useAbortableRequest();
const MILLISECONDS_PER_MINUTE = 60000;
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
  activities.value.filter(activity => activity.status === 'pending')
);
const date = value =>
  new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
const load = async () => {
  error.value = '';
  try {
    const result = await run(() => dealsAPI.activities(props.deal.id).get());
    if (result) activities.value = result.data;
  } catch {
    error.value = t('CRM.ACTIVITY_LOAD_ERROR');
  }
};
const open = async (activity = null) => {
  error.value = '';
  try {
    agents.value = (await AgentsAPI.get()).data;
    editingId.value = activity?.id || null;
    let local = '';
    if (activity) {
      const due = new Date(activity.due_at);
      local = new Date(
        due.getTime() - due.getTimezoneOffset() * MILLISECONDS_PER_MINUTE
      ).toISOString();
    }
    draft.value = {
      activity_type: activity?.activity_type || 'task',
      title: activity?.title || '',
      date: local.slice(0, 10),
      time: local.slice(11, 16),
      owner_id: activity?.owner_id ?? props.deal.owner_id ?? '',
      description: activity?.description || '',
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
  });
};
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
      <div class="flex flex-wrap gap-2">
        <Button
          :label="t('CRM.ACTIVITY_COMPLETE')"
          size="sm"
          :disabled="saving"
          @click="mutate(activity.id, { status: 'completed' })"
        />
        <Button
          :label="t('CRM.EDIT_ACTIVITY')"
          size="sm"
          variant="faded"
          :disabled="saving"
          @click="open(activity)"
        />
        <Button
          :label="t('CRM.ACTIVITY_CANCEL')"
          size="sm"
          color="ruby"
          variant="ghost"
          :disabled="saving"
          @click="mutate(activity.id, { status: 'cancelled' })"
        />
      </div>
    </article>
    <Dialog
      ref="editor"
      :title="t(editingId ? 'CRM.EDIT_ACTIVITY' : 'CRM.NEW_ACTIVITY')"
      width="2xl"
      :show-confirm-button="false"
      :show-cancel-button="false"
    >
      <form class="flex flex-col gap-4" @submit.prevent="save">
        <fieldset :disabled="saving" class="flex flex-col gap-4 min-w-0">
          <div class="flex flex-col gap-2 text-sm text-n-slate-12">
            <span>{{ t('CRM.ACTIVITY_TYPE') }}</span
            ><ComboBox v-model="draft.activity_type" :options="typeOptions" />
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
            ><ComboBox v-model="draft.owner_id" :options="ownerOptions" />
          </div>
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
