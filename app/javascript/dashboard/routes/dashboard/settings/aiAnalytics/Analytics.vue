<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useLocale } from 'shared/composables/useLocale';
import Select from 'dashboard/components-next/select/Select.vue';
import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';
import {
  EMPTY,
  dateOnly,
  formatDayMonth,
  formatNumber,
  formatPercent,
  formatTime,
  formatUsd,
} from './analyticsFormat';
import {
  averagePerDay,
  outcomeOf,
  peakOf,
  periodDays,
} from './analyticsMetrics';
import { buildActivityCsv, csvFilename, downloadCsv } from './analyticsCsv';
import { estimateCost } from './modelPricing';
import ActivityChart from './components/ActivityChart.vue';
import AnalyticsCard from './components/AnalyticsCard.vue';
import DetailTable from './components/DetailTable.vue';
import KnowledgeCard from './components/KnowledgeCard.vue';
import KpiCard from './components/KpiCard.vue';
import OutcomeCard from './components/OutcomeCard.vue';
import ResponderComparison from './components/ResponderComparison.vue';
import TokensCard from './components/TokensCard.vue';
import ToolsCard from './components/ToolsCard.vue';
import './analyticsTheme.css';

const { t } = useI18n();
const { resolvedLocale } = useLocale();
const locale = computed(() => resolvedLocale.value);

const loading = ref(true);
const failed = ref(false);
const data = ref(null);
const updatedAt = ref(null);
const filters = ref({ period: '7d', ai_agent_id: '', inbox_id: '' });
const start = ref('');
const end = ref('');
const key = name => t(`AI_ANALYTICS.${name}`);

const periodOptions = computed(() =>
  ['today', '7d', '30d', 'month', 'custom'].map(value => ({
    value,
    label: key(`PERIOD_${value.toUpperCase()}`),
  }))
);
const agentOptions = computed(() => [
  { value: '', label: key('ALL') },
  ...(data.value?.agents || []).map(item => ({
    value: item.id,
    label: item.name,
  })),
]);
const inboxOptions = computed(() => [
  { value: '', label: key('ALL') },
  ...(data.value?.inboxes || []).map(item => ({
    value: item.id,
    label: item.name,
  })),
]);

const summary = computed(() => data.value?.summary || null);
const billing = computed(() => data.value?.billing || null);
const days = computed(() => data.value?.timeseries || []);

// The days of the period as "01/11 a 11/11". A custom period shows the dates that were typed; the others, the dates the
// API answered with, which are the ones the table below is made of.
const interval = computed(() => {
  const from =
    filters.value.period === 'custom'
      ? start.value
      : dateOnly(data.value?.filters?.start_at);
  const to =
    filters.value.period === 'custom'
      ? end.value
      : dateOnly(data.value?.filters?.end_at);
  if (!from || !to) return '';
  if (from === to) return formatDayMonth(from, locale.value);
  return t('AI_ANALYTICS.PERIOD_RANGE', {
    start: formatDayMonth(from, locale.value),
    end: formatDayMonth(to, locale.value),
  });
});
const periodCaption = computed(() => {
  const label = periodOptions.value.find(
    option => option.value === filters.value.period
  )?.label;
  return interval.value
    ? t('AI_ANALYTICS.PERIOD_WITH_RANGE', { label, range: interval.value })
    : label;
});
const updatedText = computed(() =>
  updatedAt.value
    ? t('AI_ANALYTICS.UPDATED_AT', {
        time: formatTime(updatedAt.value, locale.value),
      })
    : ''
);

const cost = computed(() => estimateCost(billing.value?.models));
const outcome = computed(() => outcomeOf(summary.value || {}));
const fmt = (value, digits = 0) => formatNumber(value, locale.value, digits);
const column = name => days.value.map(day => Number(day[name] || 0));

const kpis = computed(() => {
  const peak = peakOf(days.value, 'messages');
  const average = averagePerDay(
    summary.value?.conversations,
    periodDays(days.value)
  );
  const otherBots = Number(summary.value?.other_bot_messages || 0);
  return [
    {
      key: 'conversations',
      label: key('CONVERSATIONS'),
      info: key('CONVERSATIONS_INFO'),
      color: 'var(--an-conversations)',
      value: fmt(summary.value?.conversations),
      spark: column('conversations'),
      context:
        average == null
          ? EMPTY
          : t('AI_ANALYTICS.AVERAGE_PER_DAY', { value: fmt(average, 1) }),
    },
    {
      key: 'messages',
      label: key('MESSAGES'),
      info: otherBots
        ? `${key('MESSAGES_INFO')} ${t('AI_ANALYTICS.MESSAGES_INFO_BOTS', { count: fmt(otherBots) })}`
        : key('MESSAGES_INFO'),
      color: 'var(--an-ai)',
      value: fmt(summary.value?.messages),
      spark: column('messages'),
      context: peak
        ? t('AI_ANALYTICS.PEAK_ON', {
            value: fmt(peak.value),
            date: formatDayMonth(peak.date, locale.value),
          })
        : EMPTY,
    },
    {
      key: 'handoffs',
      label: key('HANDOFFS'),
      info: key('HANDOFFS_INFO'),
      color: 'var(--an-people)',
      value: fmt(summary.value?.handoffs),
      bar: {
        share: outcome.value.handoffShare,
        label: formatPercent(outcome.value.handoffShare, locale.value),
      },
      context:
        outcome.value.handoffShare == null
          ? EMPTY
          : t('AI_ANALYTICS.SHARE_OF_CONVERSATIONS', {
              share: formatPercent(outcome.value.handoffShare, locale.value),
              count: fmt(outcome.value.conversations),
            }),
    },
    {
      key: 'tokens',
      label: key('TOKENS'),
      info: key('TOKENS_INFO'),
      color: 'var(--an-tokens)',
      value: fmt(billing.value?.total_tokens),
      spark: column('tokens'),
      context:
        cost.value == null
          ? EMPTY
          : t('AI_ANALYTICS.COST_LINE', {
              value: formatUsd(cost.value, locale.value),
            }),
    },
  ];
});

const activitySeries = computed(() => [
  {
    key: 'messages',
    label: key('SERIES_MESSAGES'),
    color: 'var(--an-ai)',
    width: 2.5,
    area: true,
  },
  {
    key: 'turns',
    label: key('SERIES_TURNS'),
    color: 'var(--an-turns)',
    width: 2,
    area: false,
  },
  {
    key: 'conversations',
    label: key('SERIES_CONVERSATIONS'),
    color: 'var(--an-conversations)',
    width: 2,
    area: false,
  },
]);
const hasActivity = computed(
  () =>
    Number(summary.value?.messages || 0) > 0 ||
    Number(summary.value?.turns || 0) > 0 ||
    Number(billing.value?.credits_consumed || 0) > 0
);

let requestId = 0;
const rangeIsValid = () =>
  filters.value.period !== 'custom' ||
  (start.value && end.value && start.value <= end.value);
const load = async () => {
  if (!rangeIsValid()) return;
  requestId += 1;
  const currentRequest = requestId;
  loading.value = true;
  failed.value = false;
  try {
    const params = { ...filters.value };
    if (params.period === 'custom') {
      // Whole days of the account: the server puts them in its own time zone (the one chosen for the reports).
      params.start_date = start.value;
      params.end_date = end.value;
    }
    const response = await aiAnalyticsAPI.show(params);
    if (currentRequest === requestId) {
      data.value = response.data;
      updatedAt.value = new Date();
    }
  } catch {
    if (currentRequest === requestId) failed.value = true;
  } finally {
    if (currentRequest === requestId) loading.value = false;
  }
};

// The CSV is the detailed table as it is on screen, with the filters in use.
const exportCsv = () => {
  if (!data.value) return;
  const withCredits = billing.value?.mode === 'platform';
  const content = buildActivityCsv({
    rows: [...days.value].reverse(),
    total: {
      conversations: summary.value.conversations,
      turns: summary.value.turns,
      messages: summary.value.messages,
      tokens: billing.value?.total_tokens,
      credits: billing.value?.credits_consumed,
    },
    labels: {
      date: key('DATE'),
      conversations: key('CONVERSATIONS'),
      turns: key('TURNS'),
      messages: key('MESSAGES'),
      tokens: key('TOKENS'),
      credits: key('CREDITS_USED'),
      total: key('CSV_TOTAL'),
    },
    withCredits,
  });
  downloadCsv(content, csvFilename());
};

onMounted(load);
</script>

<template>
  <!-- The scroller is the whole area (so its scrollbar sits at the edge of the window). It is `relative` so nothing
       absolutely positioned inside, like the hidden table caption, can reach out and make the page itself scroll. -->
  <main
    class="analytics-root relative h-full min-h-0 w-full overflow-y-auto overscroll-contain text-n-slate-12"
  >
    <div
      class="mx-auto flex w-full min-w-0 max-w-[120rem] flex-col gap-4 px-4 pb-8 sm:px-6"
    >
      <header
        class="flex shrink-0 flex-wrap items-end justify-between gap-x-6 gap-y-4"
      >
        <div class="min-w-0">
          <h1 class="m-0 text-xl font-semibold tracking-tight">
            {{ key('TITLE') }}
          </h1>
          <p class="m-0 mt-1 text-sm text-n-slate-11">{{ key('SUBTITLE') }}</p>
        </div>
        <div class="flex flex-wrap items-end gap-3" data-test="filters">
          <label class="min-w-0 text-xs font-medium text-n-slate-11">
            {{ key('PERIOD') }}
            <Select
              v-model="filters.period"
              :options="periodOptions"
              :aria-label="key('PERIOD')"
              class="mt-1 [&_select]:min-h-11"
              data-test="period-select"
              @update:model-value="load"
            />
            <span
              v-if="interval"
              class="mt-1 block text-xs tabular-nums text-n-slate-11"
              data-test="period-interval"
              >{{ periodCaption }}</span
            >
          </label>
          <label class="min-w-0 text-xs font-medium text-n-slate-11">
            {{ key('AGENT') }}
            <Select
              v-model="filters.ai_agent_id"
              :options="agentOptions"
              :aria-label="key('AGENT')"
              class="mt-1 [&_select]:min-h-11"
              @update:model-value="load"
            />
          </label>
          <label class="min-w-0 text-xs font-medium text-n-slate-11">
            {{ key('INBOX') }}
            <Select
              v-model="filters.inbox_id"
              :options="inboxOptions"
              :aria-label="key('INBOX')"
              class="mt-1 [&_select]:min-h-11"
              @update:model-value="load"
            />
          </label>
          <div class="flex flex-col items-start gap-1">
            <button
              type="button"
              class="flex min-h-11 items-center gap-2 rounded-lg border border-n-weak px-4 text-sm font-medium text-n-slate-12 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="!data || loading"
              data-test="export-csv"
              @click="exportCsv"
            >
              <span class="i-lucide-download size-4" aria-hidden="true" />
              {{ key('EXPORT_CSV') }}
            </button>
            <span
              v-if="updatedText"
              class="text-xs tabular-nums text-n-slate-11"
              data-test="updated-at"
              >{{ updatedText }}</span
            >
          </div>
        </div>
      </header>

      <div
        v-if="filters.period === 'custom'"
        class="flex shrink-0 flex-wrap items-end gap-3"
        data-test="custom-range"
      >
        <label class="text-xs text-n-slate-11"
          >{{ key('START')
          }}<input
            v-model="start"
            type="date"
            :max="end || undefined"
            class="!mb-0 mt-1 min-h-11 !w-auto"
        /></label>
        <label class="text-xs text-n-slate-11"
          >{{ key('END')
          }}<input
            v-model="end"
            type="date"
            :min="start || undefined"
            class="!mb-0 mt-1 min-h-11 !w-auto"
        /></label>
        <button
          type="button"
          class="min-h-11 rounded-lg bg-n-blue-9 px-4 text-sm text-white disabled:opacity-50"
          :disabled="!start || !end || start > end"
          @click="load"
        >
          {{ key('APPLY') }}
        </button>
      </div>

      <section
        class="grid shrink-0 grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4"
        :aria-label="key('TITLE')"
        data-test="kpis"
      >
        <KpiCard
          v-for="kpi in kpis"
          :key="kpi.key"
          :label="kpi.label"
          :info="kpi.info"
          :color="kpi.color"
          :value="kpi.value"
          :context="kpi.context"
          :spark="kpi.spark"
          :bar="kpi.bar"
          :loading="loading"
          :data-test="`kpi-${kpi.key}`"
        />
      </section>

      <div class="flex flex-wrap gap-4">
        <AnalyticsCard
          class="min-w-0 flex-[2_1_30rem]"
          :title="key('TIMESERIES')"
          :info="key('TIMESERIES_INFO')"
          :period="periodCaption"
          :loading="loading"
          :error="failed"
          :empty="!hasActivity"
          :empty-text="key('EMPTY')"
          data-test="activity-card"
          @retry="load"
        >
          <ActivityChart
            :points="days"
            :series="activitySeries"
            :totals="{
              messages: summary?.messages,
              turns: summary?.turns,
              conversations: summary?.conversations,
            }"
            :tokens-label="key('TOKENS')"
            :aria-label="key('TIMESERIES_ARIA')"
            :scroll-label="key('TIMESERIES_SCROLL')"
            :locale="locale"
          />
        </AnalyticsCard>
        <OutcomeCard
          class="min-w-0 flex-[1_1_18rem]"
          :summary="summary"
          :timeseries="days"
          :period="periodCaption"
          :locale="locale"
          :loading="loading"
          :error="failed"
          @retry="load"
        />
      </div>

      <div class="flex flex-wrap gap-4">
        <TokensCard
          class="min-w-0 flex-[3_1_30rem]"
          :billing="billing"
          :summary="summary"
          :timeseries="days"
          :period="periodCaption"
          :locale="locale"
          :loading="loading"
          :error="failed"
          @retry="load"
        />
        <ResponderComparison class="min-w-0 flex-[2_1_22rem]" />
      </div>

      <div class="flex flex-wrap gap-4">
        <ToolsCard
          class="min-w-0 flex-[1_1_26rem]"
          :tools="data?.tools"
          :period="periodCaption"
          :locale="locale"
          :loading="loading"
          :error="failed"
          @retry="load"
        />
        <KnowledgeCard
          class="min-w-0 flex-[1_1_26rem]"
          :knowledge="data?.knowledge"
          :summary="summary"
          :period="periodCaption"
          :locale="locale"
          :loading="loading"
          :error="failed"
          @retry="load"
        />
      </div>

      <DetailTable
        :timeseries="days"
        :summary="summary"
        :billing="billing"
        :period="periodCaption"
        :locale="locale"
        :loading="loading"
        :error="failed"
        @retry="load"
      />
    </div>
  </main>
</template>
