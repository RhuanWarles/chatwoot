<script setup>
import { computed, onMounted, ref, useId } from 'vue';
import { useI18n } from 'vue-i18n';
import { useLocale } from 'shared/composables/useLocale';
import Select from 'dashboard/components-next/select/Select.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';
import {
  EMPTY,
  formatMonth,
  formatNumber,
  formatPercent,
} from '../analyticsFormat';
import {
  isCurrentMonth,
  monthlyAverages,
  percentOf,
} from '../analyticsMetrics';
import AnalyticsCard from './AnalyticsCard.vue';
import StackedMonthBars from './StackedMonthBars.vue';
import StatTile from './StatTile.vue';

// "AI vs people": month by month, how many public replies came from the AI and how many from people. It has its own
// period (the last N months) and its own filters, apart from the ones at the top of the screen.
const MONTH_CHOICES = [3, 6, 12, 24];
const { t } = useI18n();
const { resolvedLocale } = useLocale();
const locale = computed(() => resolvedLocale.value);
const filtersId = useId();

const data = ref(null);
const people = ref([]);
const segments = ref([]);
const loading = ref(true);
const error = ref('');
const showFilters = ref(false);
const filters = ref({
  months: 6,
  owner_ids: [],
  answered_by: [],
  segment_ids: [],
});
let requestId = 0;

const number = value => formatNumber(value, locale.value, 2);
const percent = value => formatPercent(value, locale.value);

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
const activeFilters = computed(
  () =>
    filters.value.owner_ids.length +
    filters.value.answered_by.length +
    filters.value.segment_ids.length
);
const filtersLabel = computed(() =>
  activeFilters.value
    ? t('CRM.RESPONDER_REPORT.FILTERS_ACTIVE', { count: activeFilters.value })
    : t('CRM.RESPONDER_REPORT.FILTERS')
);
const periodLabel = computed(() =>
  t('CRM.RESPONDER_REPORT.MONTHS', { count: filters.value.months })
);

const rows = computed(() => data.value?.months ?? []);
const totals = computed(() => data.value?.totals);
const replies = computed(
  () => (totals.value?.ai_replies ?? 0) + (totals.value?.human_replies ?? 0)
);
// With nothing to divide there is no share: "—", never a 0% that reads as "the AI answered nothing".
const aiShare = computed(() => (replies.value ? totals.value.ai_share : null));
const aiOnlyShare = computed(() =>
  totals.value?.conversations ? totals.value.ai_only_share : null
);
const averages = computed(() => monthlyAverages(rows.value));
const changeText = computed(() => {
  const { change } = averages.value;
  if (change == null) return '';
  const value = percent(Math.abs(change));
  return t(
    change >= 0
      ? 'CRM.RESPONDER_REPORT.CHANGE_UP'
      : 'CRM.RESPONDER_REPORT.CHANGE_DOWN',
    { value }
  );
});
const hasMonthInProgress = computed(() =>
  rows.value.some(row => isCurrentMonth(row.month))
);
const legend = computed(() => [
  {
    key: 'ai',
    label: t('CRM.RESPONDER_REPORT.LEGEND_AI'),
    color: 'var(--an-ai)',
    count: totals.value?.ai_replies,
    share: percentOf(totals.value?.ai_replies, replies.value),
  },
  {
    key: 'human',
    label: t('CRM.RESPONDER_REPORT.LEGEND_HUMAN'),
    color: 'var(--an-people)',
    count: totals.value?.human_replies,
    share: percentOf(totals.value?.human_replies, replies.value),
  },
]);

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
  <AnalyticsCard
    :title="t('CRM.RESPONDER_REPORT.TITLE')"
    :period="periodLabel"
    :loading="loading && !data"
    :error="!!error"
    :error-text="error"
    data-test="responder-report"
    @retry="load"
  >
    <template #actions>
      <Select
        v-model="filters.months"
        :options="monthOptions"
        :aria-label="t('CRM.RESPONDER_REPORT.FILTER_MONTHS')"
        class="[&_select]:min-h-11"
        data-test="months-select"
        @update:model-value="load"
      />
      <button
        type="button"
        class="flex min-h-11 items-center gap-1.5 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-expanded="showFilters"
        :aria-controls="filtersId"
        data-test="filters-button"
        @click="showFilters = !showFilters"
      >
        <span class="i-lucide-list-filter size-4" aria-hidden="true" />
        {{ filtersLabel }}
      </button>
    </template>

    <template #toolbar>
      <div
        v-if="showFilters"
        :id="filtersId"
        class="mt-4 grid grid-cols-1 gap-3 rounded-lg bg-n-alpha-1 p-3 sm:grid-cols-3"
        data-test="filters-panel"
      >
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
    </template>

    <div
      v-if="data"
      class="flex flex-col gap-4 transition-opacity"
      :class="loading ? 'opacity-60' : ''"
      :aria-busy="loading"
    >
      <dl class="m-0 grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatTile
          :label="t('CRM.RESPONDER_REPORT.SHARE_AI')"
          :info="t('CRM.RESPONDER_REPORT.SHARE_AI_INFO')"
          :value="percent(aiShare)"
          :tone="aiShare == null ? 'muted' : 'neutral'"
          data-test="total-share"
        />
        <StatTile
          :label="t('CRM.RESPONDER_REPORT.SHARE_AI_ONLY')"
          :info="t('CRM.RESPONDER_REPORT.SHARE_AI_ONLY_INFO')"
          :value="percent(aiOnlyShare)"
          :tone="aiOnlyShare == null ? 'muted' : 'neutral'"
          data-test="ai-only-share"
        />
        <StatTile
          :label="t('CRM.RESPONDER_REPORT.REPLIES')"
          :info="t('CRM.RESPONDER_REPORT.REPLIES_INFO')"
          :value="number(replies)"
          data-test="replies-total"
        />
      </dl>

      <p
        v-if="!replies"
        class="m-0 text-sm text-n-slate-11"
        data-test="responder-empty"
      >
        {{ t('CRM.RESPONDER_REPORT.EMPTY') }}
      </p>

      <template v-else>
        <StackedMonthBars :rows="rows" :locale="locale" />

        <ul
          class="m-0 flex list-none flex-wrap gap-x-5 gap-y-1.5 p-0 text-xs text-n-slate-11"
          data-test="responder-legend"
        >
          <li
            v-for="item in legend"
            :key="item.key"
            class="flex items-center gap-1.5"
          >
            <span
              class="size-2.5 rounded-sm"
              :style="{ background: item.color }"
              aria-hidden="true"
            />
            {{ item.label }}
            <strong class="font-semibold tabular-nums text-n-slate-12">
              {{ number(item.count) }} ({{ percent(item.share) }})
            </strong>
          </li>
          <li
            v-if="hasMonthInProgress"
            class="flex items-center gap-1.5"
            data-test="in-progress-legend"
          >
            <span
              class="hatched size-2.5 rounded-sm bg-[var(--an-ai)]"
              aria-hidden="true"
            />
            {{ t('CRM.RESPONDER_REPORT.IN_PROGRESS') }}
          </li>
        </ul>

        <div
          class="flex flex-wrap items-center gap-x-3 gap-y-1 border-t border-n-weak pt-3 text-sm"
          data-test="average-per-day"
        >
          <span class="text-n-slate-11">
            {{ t('CRM.RESPONDER_REPORT.AVERAGE_PER_DAY') }}:
          </span>
          <span class="tabular-nums text-n-slate-12">
            <strong class="font-semibold">{{
              t('CRM.RESPONDER_REPORT.AVERAGE_CURRENT', {
                value: formatNumber(averages.current, locale, 1),
              })
            }}</strong>
            ·
            {{
              t('CRM.RESPONDER_REPORT.AVERAGE_PREVIOUS', {
                value: formatNumber(averages.previous, locale, 1),
              })
            }}
          </span>
          <span
            v-if="averages.change != null"
            class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-semibold tabular-nums"
            :class="
              averages.change >= 0
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-ruby-3 text-n-ruby-11'
            "
            :aria-label="changeText"
            data-test="average-change"
          >
            <span aria-hidden="true">{{
              averages.change >= 0 ? '▲' : '▼'
            }}</span>
            {{ percent(Math.abs(averages.change)) }}
          </span>
        </div>

        <details class="text-xs" data-test="month-details">
          <summary
            class="min-h-11 cursor-pointer py-3 font-medium text-n-slate-11 hover:text-n-slate-12"
          >
            {{ t('CRM.RESPONDER_REPORT.VIEW_BY_MONTH') }}
          </summary>
          <div class="overflow-x-auto">
            <table class="w-full text-start text-xs tabular-nums">
              <thead class="text-n-slate-11">
                <tr>
                  <th scope="col" class="py-1 pe-3 text-start font-medium">
                    {{ t('CRM.RESPONDER_REPORT.COL_MONTH') }}
                  </th>
                  <th scope="col" class="py-1 pe-3 text-end font-medium">
                    {{ t('CRM.RESPONDER_REPORT.LEGEND_AI') }}
                  </th>
                  <th scope="col" class="py-1 pe-3 text-end font-medium">
                    {{ t('CRM.RESPONDER_REPORT.LEGEND_HUMAN') }}
                  </th>
                  <th scope="col" class="py-1 pe-3 text-end font-medium">
                    {{ t('CRM.RESPONDER_REPORT.COL_SHARE') }}
                  </th>
                  <th scope="col" class="py-1 text-end font-medium">
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
                  <th scope="row" class="py-1 pe-3 text-start font-normal">
                    {{ formatMonth(row.month, locale) }}
                  </th>
                  <template v-if="row.ai_replies + row.human_replies">
                    <td class="py-1 pe-3 text-end">
                      {{ number(row.ai_replies) }}
                    </td>
                    <td class="py-1 pe-3 text-end">
                      {{ number(row.human_replies) }}
                    </td>
                    <td class="py-1 pe-3 text-end">
                      {{ percent(row.ai_share) }}
                    </td>
                    <td class="py-1 text-end">
                      {{
                        percent(
                          row.conversations.total ? row.ai_only_share : null
                        )
                      }}
                    </td>
                  </template>
                  <td v-else colspan="4" class="py-1 text-end text-n-slate-10">
                    {{ EMPTY }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </details>
      </template>
    </div>
  </AnalyticsCard>
</template>
