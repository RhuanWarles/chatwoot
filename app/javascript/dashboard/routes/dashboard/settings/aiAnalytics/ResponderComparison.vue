<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useLocale } from 'shared/composables/useLocale';
import Select from 'dashboard/components-next/select/Select.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';

const MONTH_CHOICES = [3, 6, 12, 24];
const { t } = useI18n();
const { resolvedLocale } = useLocale();

const data = ref(null);
const people = ref([]);
const segments = ref([]);
const loading = ref(true);
const error = ref('');
const filters = ref({
  months: 6,
  owner_ids: [],
  answered_by: [],
  segment_ids: [],
});
let requestId = 0;

const number = value =>
  Number(value || 0).toLocaleString(resolvedLocale.value, {
    maximumFractionDigits: 2,
  });
const percent = value => `${number(value)}%`;
const monthLabel = month =>
  new Intl.DateTimeFormat(resolvedLocale.value, {
    month: 'short',
    year: '2-digit',
    timeZone: 'UTC',
  }).format(new Date(`${month}-01T00:00:00Z`));

const monthOptions = computed(() =>
  MONTH_CHOICES.map(value => ({
    value,
    label: t('CRM.RESPONDER_REPORT.MONTHS', { count: value }),
  }))
);
const ownerOptions = computed(() => [
  ...people.value.map(({ id, name }) => ({ value: id, label: name })),
  { value: 'none', label: t('CRM.FILTER_UNASSIGNED') },
]);
const answeredByOptions = computed(() => [
  { value: 'ai', label: t('CRM.FILTER_AI') },
  ...people.value.map(({ id, name }) => ({ value: id, label: name })),
]);
const segmentOptions = computed(() => [
  ...segments.value.map(({ id, name }) => ({ value: id, label: name })),
  { value: 'none', label: t('CRM.NO_SEGMENT') },
]);

const rows = computed(() => data.value?.months ?? []);
const totals = computed(() => data.value?.totals);
const hasReplies = computed(
  () => (totals.value?.ai_replies ?? 0) + (totals.value?.human_replies ?? 0) > 0
);
const highest = computed(() =>
  Math.max(1, ...rows.value.map(row => row.ai_replies + row.human_replies))
);
const barHeight = row => {
  const total = row.ai_replies + row.human_replies;
  return total ? `${Math.max(2, (total / highest.value) * 100)}%` : '0%';
};

const load = async () => {
  requestId += 1;
  const current = requestId;
  loading.value = true;
  error.value = '';
  try {
    const response = await aiAnalyticsAPI.replies(filters.value);
    if (current !== requestId) return;
    data.value = response.data;
    people.value = response.data.people;
    segments.value = response.data.segments;
  } catch {
    if (current === requestId)
      error.value = t('CRM.RESPONDER_REPORT.LOAD_ERROR');
  } finally {
    if (current === requestId) loading.value = false;
  }
};
onMounted(load);
</script>

<template>
  <section
    class="flex min-w-0 flex-col gap-4 rounded-2xl border border-n-container bg-n-surface-1 p-4 shadow-sm"
    data-test="responder-report"
  >
    <header>
      <h2 class="text-sm font-semibold">
        {{ t('CRM.RESPONDER_REPORT.TITLE') }}
      </h2>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ t('CRM.RESPONDER_REPORT.SUBTITLE') }}
      </p>
    </header>

    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
      <label class="min-w-0 text-xs font-medium text-n-slate-11">
        {{ t('CRM.RESPONDER_REPORT.FILTER_MONTHS') }}
        <Select
          v-model="filters.months"
          :options="monthOptions"
          class="mt-1 !w-full [&_select]:w-full"
          @update:model-value="load"
        />
      </label>
      <div class="min-w-0 text-xs font-medium text-n-slate-11">
        <span class="mb-1 block">{{ t('CRM.OWNER') }}</span>
        <TagMultiSelectComboBox
          v-model="filters.owner_ids"
          :options="ownerOptions"
          :placeholder="t('CRM.RESPONDER_REPORT.ALL')"
          @update:model-value="load"
        />
      </div>
      <div class="min-w-0 text-xs font-medium text-n-slate-11">
        <span class="mb-1 block">{{ t('CRM.FILTER_ANSWERED_BY') }}</span>
        <TagMultiSelectComboBox
          v-model="filters.answered_by"
          :options="answeredByOptions"
          :placeholder="t('CRM.RESPONDER_REPORT.ALL')"
          @update:model-value="load"
        />
      </div>
      <div class="min-w-0 text-xs font-medium text-n-slate-11">
        <span class="mb-1 block">{{ t('CRM.FILTER_SEGMENT') }}</span>
        <TagMultiSelectComboBox
          v-model="filters.segment_ids"
          :options="segmentOptions"
          :placeholder="t('CRM.RESPONDER_REPORT.ALL')"
          @update:model-value="load"
        />
      </div>
    </div>

    <p
      v-if="error"
      role="alert"
      class="rounded-lg bg-n-ruby-3 px-3 py-2 text-sm text-n-ruby-11"
    >
      {{ error }}
    </p>

    <p v-else-if="loading && !data" class="py-8 text-sm text-n-slate-11">
      {{ t('CRM.RESPONDER_REPORT.LOADING') }}
    </p>

    <template v-else-if="data">
      <dl class="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div class="rounded-xl bg-n-alpha-2 p-3">
          <dt class="text-xs text-n-slate-11">
            {{ t('CRM.RESPONDER_REPORT.SHARE_AI') }}
          </dt>
          <dd class="m-0 text-xl font-semibold" data-test="total-share">
            {{ percent(totals.ai_share) }}
          </dd>
        </div>
        <div class="rounded-xl bg-n-alpha-2 p-3">
          <dt class="text-xs text-n-slate-11">
            {{ t('CRM.RESPONDER_REPORT.SHARE_AI_ONLY') }}
          </dt>
          <dd class="m-0 text-xl font-semibold">
            {{ percent(totals.ai_only_share) }}
          </dd>
        </div>
        <div class="rounded-xl bg-n-alpha-2 p-3">
          <dt class="text-xs text-n-slate-11">
            {{ t('CRM.RESPONDER_REPORT.REPLIES') }}
          </dt>
          <dd class="m-0 text-xl font-semibold">
            {{ number(totals.ai_replies + totals.human_replies) }}
          </dd>
        </div>
      </dl>

      <p v-if="!hasReplies" class="py-6 text-sm text-n-slate-11">
        {{ t('CRM.RESPONDER_REPORT.EMPTY') }}
      </p>

      <template v-else>
        <div
          class="flex h-52 items-stretch gap-3"
          role="img"
          :aria-label="t('CRM.RESPONDER_REPORT.TITLE')"
        >
          <div
            v-for="row in rows"
            :key="row.month"
            class="flex min-w-0 flex-1 flex-col items-center gap-1"
            data-test="month-bar"
          >
            <span class="text-xs font-medium">{{ percent(row.ai_share) }}</span>
            <div class="flex w-full flex-1 items-end justify-center">
              <div
                class="flex w-full max-w-12 flex-col justify-end overflow-hidden rounded-t"
                :style="{ height: barHeight(row) }"
              >
                <div
                  class="bg-n-blue-9"
                  :style="{ flexGrow: row.human_replies }"
                />
                <div
                  class="bg-n-teal-9"
                  :style="{ flexGrow: row.ai_replies }"
                />
              </div>
            </div>
            <span class="text-xs text-n-slate-11">{{
              monthLabel(row.month)
            }}</span>
          </div>
        </div>

        <ul class="m-0 flex list-none gap-4 p-0 text-xs text-n-slate-11">
          <li class="flex items-center gap-1.5">
            <span class="size-2.5 rounded-sm bg-n-teal-9" aria-hidden="true" />
            {{ t('CRM.RESPONDER_REPORT.LEGEND_AI') }}
          </li>
          <li class="flex items-center gap-1.5">
            <span class="size-2.5 rounded-sm bg-n-blue-9" aria-hidden="true" />
            {{ t('CRM.RESPONDER_REPORT.LEGEND_HUMAN') }}
          </li>
        </ul>

        <div class="overflow-x-auto">
          <table class="w-full text-start text-xs">
            <thead class="text-n-slate-11">
              <tr>
                <th class="py-1 pe-3 text-start font-medium">
                  {{ t('CRM.RESPONDER_REPORT.COL_MONTH') }}
                </th>
                <th class="py-1 pe-3 text-end font-medium">
                  {{ t('CRM.RESPONDER_REPORT.LEGEND_AI') }}
                </th>
                <th class="py-1 pe-3 text-end font-medium">
                  {{ t('CRM.RESPONDER_REPORT.LEGEND_HUMAN') }}
                </th>
                <th class="py-1 pe-3 text-end font-medium">
                  {{ t('CRM.RESPONDER_REPORT.COL_SHARE') }}
                </th>
                <th class="py-1 text-end font-medium">
                  {{ t('CRM.RESPONDER_REPORT.COL_AI_ONLY') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in rows"
                :key="row.month"
                class="border-t border-n-weak"
                data-test="month-row"
              >
                <td class="py-1 pe-3">{{ monthLabel(row.month) }}</td>
                <td class="py-1 pe-3 text-end">{{ number(row.ai_replies) }}</td>
                <td class="py-1 pe-3 text-end">
                  {{ number(row.human_replies) }}
                </td>
                <td class="py-1 pe-3 text-end">{{ percent(row.ai_share) }}</td>
                <td class="py-1 text-end">{{ percent(row.ai_only_share) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </template>
  </section>
</template>
