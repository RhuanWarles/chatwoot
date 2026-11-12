<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useLocale } from 'shared/composables/useLocale';
import { useAccount } from 'dashboard/composables/useAccount';
import Select from 'dashboard/components-next/select/Select.vue';
import generalDashboardAPI from 'dashboard/api/generalDashboard';
import {
  EMPTY,
  dateOnly,
  formatDayMonth,
  formatNumber,
  formatPercent,
  formatTime,
  formatUsd,
} from '../settings/aiAnalytics/analyticsFormat';
import {
  percentChange,
  percentOf,
  ratio,
} from '../settings/aiAnalytics/analyticsMetrics';
import { estimateCost } from '../settings/aiAnalytics/modelPricing';
import AnalyticsCard from '../settings/aiAnalytics/components/AnalyticsCard.vue';
import KpiCard from '../settings/aiAnalytics/components/KpiCard.vue';
import { brlFormatter } from '../crm/components/currencyHelpers';
import '../settings/aiAnalytics/analyticsTheme.css';
import AiCard from './components/AiCard.vue';
import BlastsCard from './components/BlastsCard.vue';
import CrmCard from './components/CrmCard.vue';
import HeatmapCard from './components/HeatmapCard.vue';
import RepliesChart from './components/RepliesChart.vue';
import TeamCard from './components/TeamCard.vue';
import WaitingCard from './components/WaitingCard.vue';
import { formatSeconds, formatWaiting } from './dashboardMetrics';

const { t } = useI18n();
const { resolvedLocale } = useLocale();
const { accountId } = useAccount();
const locale = computed(() => resolvedLocale.value);

const loading = ref(true);
const failed = ref(false);
const data = ref(null);
const updatedAt = ref(null);
const filters = ref({ period: '7d', inbox_id: '', pipeline_id: '' });
const start = ref('');
const end = ref('');

const periodOptions = computed(() =>
  ['today', '7d', '30d', 'month', 'custom'].map(value => ({
    value,
    label: t(`AI_ANALYTICS.PERIOD_${value.toUpperCase()}`),
  }))
);
const inboxOptions = computed(() => [
  { value: '', label: t('GENERAL_DASHBOARD.ALL_INBOXES') },
  ...(data.value?.inboxes || []).map(item => ({
    value: item.id,
    label: item.name,
  })),
]);

const attendance = computed(() => data.value?.attendance || null);
const ai = computed(() => data.value?.ai || null);
const crm = computed(() => data.value?.crm || null);
const blasts = computed(() => data.value?.blasts || null);
const fmt = (value, digits = 0) => formatNumber(value, locale.value, digits);

const interval = computed(() => {
  const custom = filters.value.period === 'custom';
  const from = custom ? start.value : dateOnly(data.value?.filters?.start_at);
  const to = custom ? end.value : dateOnly(data.value?.filters?.end_at);
  if (!from || !to) return '';
  if (from === to) return formatDayMonth(from, locale.value);
  return t('AI_ANALYTICS.PERIOD_RANGE', {
    start: formatDayMonth(from, locale.value),
    end: formatDayMonth(to, locale.value),
  });
});
const periodLabel = computed(
  () =>
    periodOptions.value.find(option => option.value === filters.value.period)
      ?.label
);
const periodCaption = computed(() =>
  interval.value
    ? t('AI_ANALYTICS.PERIOD_WITH_RANGE', {
        label: periodLabel.value,
        range: interval.value,
      })
    : periodLabel.value
);
const updatedText = computed(() =>
  updatedAt.value
    ? t('AI_ANALYTICS.UPDATED_AT', {
        time: formatTime(updatedAt.value, locale.value),
      })
    : ''
);

// "↑ 12% against the period before": a number that has nothing to be compared with says nothing.
const versusPrevious = (current, previous) => {
  const change = percentChange(current, previous);
  if (change === null) return '';
  const value = formatPercent(Math.abs(change), locale.value, 0);
  return t(
    change >= 0 ? 'GENERAL_DASHBOARD.VS_UP' : 'GENERAL_DASHBOARD.VS_DOWN',
    { value }
  );
};

const cost = computed(() => estimateCost(ai.value?.billing?.models));
const costPerConversation = computed(() =>
  ratio(cost.value, ai.value?.summary?.conversations)
);

const kpis = computed(() => {
  const att = attendance.value;
  const waiting = att?.waiting;
  const first = att?.first_response;
  const handled = att?.handled;
  const summary = ai.value?.summary;
  return [
    {
      key: 'activity',
      label: t('GENERAL_DASHBOARD.KPI_ACTIVITY'),
      info: t('GENERAL_DASHBOARD.KPI_ACTIVITY_INFO'),
      color: 'var(--an-conversations)',
      value: fmt(att?.activity?.conversations),
      spark: att ? att.activity.per_day.map(day => day.conversations) : null,
      sparkLabel: t('GENERAL_DASHBOARD.KPI_ACTIVITY_SPARK'),
      context:
        versusPrevious(att?.activity?.conversations, att?.activity?.previous) ||
        EMPTY,
    },
    {
      key: 'waiting',
      label: t('GENERAL_DASHBOARD.KPI_WAITING'),
      info: t('GENERAL_DASHBOARD.WAITING_INFO'),
      color: 'var(--an-attention)',
      value: fmt(waiting?.total),
      context: waiting?.total
        ? t('GENERAL_DASHBOARD.WAITING_OLDEST', {
            time: formatWaiting(waiting.oldest_minutes),
          })
        : t('GENERAL_DASHBOARD.WAITING_NONE'),
    },
    {
      key: 'first-response',
      label: t('GENERAL_DASHBOARD.KPI_FIRST_RESPONSE'),
      info: t('GENERAL_DASHBOARD.KPI_FIRST_RESPONSE_INFO'),
      color: 'var(--an-people)',
      value: formatSeconds(first?.average, locale.value),
      context:
        first?.median == null
          ? EMPTY
          : [
              t('GENERAL_DASHBOARD.MEDIAN', {
                value: formatSeconds(first.median, locale.value),
              }),
              versusPrevious(first.average, first.previous_average),
            ]
              .filter(Boolean)
              .join(' · '),
    },
    {
      key: 'ai-only',
      label: t('GENERAL_DASHBOARD.KPI_AI_ONLY'),
      info: t('GENERAL_DASHBOARD.AI_ONLY_INFO'),
      color: 'var(--an-ai)',
      value: formatPercent(handled?.ai_only_share, locale.value, 0),
      context: handled?.responded
        ? t('GENERAL_DASHBOARD.AI_ONLY_OF', {
            count: fmt(
              Math.round((handled.ai_only_share / 100) * handled.responded)
            ),
            total: fmt(handled.responded),
          })
        : EMPTY,
    },
    {
      key: 'handoffs',
      label: t('GENERAL_DASHBOARD.HANDOFFS'),
      info: t('GENERAL_DASHBOARD.HANDOFFS_INFO'),
      color: 'var(--an-people)',
      value: summary ? fmt(summary.handoffs) : EMPTY,
      context: summary?.conversations
        ? t('GENERAL_DASHBOARD.HANDOFF_OF', {
            share: formatPercent(
              percentOf(summary.handoffs, summary.conversations),
              locale.value
            ),
          })
        : EMPTY,
    },
    {
      key: 'cost',
      label: t('GENERAL_DASHBOARD.KPI_COST'),
      info: t('GENERAL_DASHBOARD.KPI_COST_INFO'),
      color: 'var(--an-tokens)',
      value: formatUsd(costPerConversation.value, locale.value),
      context:
        cost.value == null
          ? EMPTY
          : t('GENERAL_DASHBOARD.COST_TOTAL', {
              value: formatUsd(cost.value, locale.value),
            }),
    },
    {
      key: 'won',
      label: t('GENERAL_DASHBOARD.WON'),
      info: t('GENERAL_DASHBOARD.KPI_WON_INFO'),
      color: 'var(--an-neutral)',
      value: crm.value?.pipeline_id ? fmt(crm.value.won.deals) : EMPTY,
      context: crm.value?.pipeline_id
        ? t('GENERAL_DASHBOARD.WON_VALUE', {
            won: brlFormatter.format(crm.value.won.value),
            open: brlFormatter.format(crm.value.open_value),
          })
        : EMPTY,
    },
    {
      key: 'blasts',
      label: t('GENERAL_DASHBOARD.KPI_BLASTS'),
      info: t('GENERAL_DASHBOARD.BLASTS_INFO'),
      color: 'var(--an-neutral)',
      value: blasts.value?.available ? fmt(blasts.value.sent) : EMPTY,
      context: blasts.value?.sent
        ? t('GENERAL_DASHBOARD.BLASTS_REPLIED', {
            share: formatPercent(
              percentOf(blasts.value.replied, blasts.value.sent),
              locale.value,
              0
            ),
          })
        : EMPTY,
    },
  ];
});

const repliesTotal = computed(
  () =>
    Number(attendance.value?.replies?.ai || 0) +
    Number(attendance.value?.replies?.people || 0)
);
const replyLegend = computed(() =>
  [
    {
      key: 'ai',
      label: t('CRM.RESPONDER_REPORT.LEGEND_AI'),
      color: 'var(--an-ai)',
      count: attendance.value?.replies?.ai,
    },
    {
      key: 'people',
      label: t('CRM.RESPONDER_REPORT.LEGEND_HUMAN'),
      color: 'var(--an-people)',
      count: attendance.value?.replies?.people,
    },
  ].map(item => ({ ...item, share: percentOf(item.count, repliesTotal.value) }))
);

const itemTotals = item =>
  `${fmt(item.count)} (${formatPercent(item.share, locale.value, 0)})`;

let requestId = 0;
const rangeIsValid = () =>
  filters.value.period !== 'custom' ||
  (start.value && end.value && start.value <= end.value);
const load = async () => {
  if (!rangeIsValid()) return;
  requestId += 1;
  const current = requestId;
  loading.value = true;
  failed.value = false;
  try {
    const params = { ...filters.value };
    if (params.period === 'custom') {
      // Whole days of the account: the server puts them in its own time zone.
      params.start_date = start.value;
      params.end_date = end.value;
    }
    const response = await generalDashboardAPI.show(params);
    if (current === requestId) {
      data.value = response.data;
      updatedAt.value = new Date();
    }
  } catch {
    if (current === requestId) failed.value = true;
  } finally {
    if (current === requestId) loading.value = false;
  }
};
const choosePipeline = id => {
  filters.value.pipeline_id = id;
  load();
};
onMounted(load);
</script>

<template>
  <main
    class="analytics-root relative h-full min-h-0 w-full overflow-y-auto overscroll-contain text-n-slate-12"
  >
    <div
      class="mx-auto flex w-full min-w-0 max-w-[120rem] flex-col gap-4 px-4 pb-8 pt-4 sm:px-6"
    >
      <header
        class="flex shrink-0 flex-wrap items-end justify-between gap-x-6 gap-y-4"
      >
        <div class="min-w-0">
          <h1 class="m-0 text-xl font-semibold tracking-tight">
            {{ t('GENERAL_DASHBOARD.TITLE') }}
          </h1>
          <p class="m-0 mt-1 text-sm text-n-slate-11">
            {{ t('GENERAL_DASHBOARD.SUBTITLE') }}
          </p>
        </div>
        <div class="flex flex-wrap items-end gap-3" data-test="filters">
          <label class="min-w-0 text-xs font-medium text-n-slate-11">
            {{ t('AI_ANALYTICS.PERIOD') }}
            <Select
              v-model="filters.period"
              :options="periodOptions"
              :aria-label="t('AI_ANALYTICS.PERIOD')"
              class="mt-1 [&_select]:min-h-11"
              data-test="period-select"
              @update:model-value="load"
            />
            <span
              v-if="interval"
              class="mt-1 block text-xs tabular-nums text-n-slate-11"
              data-test="period-interval"
            >
              {{ periodCaption }}
            </span>
          </label>
          <label class="min-w-0 text-xs font-medium text-n-slate-11">
            {{ t('AI_ANALYTICS.INBOX') }}
            <Select
              v-model="filters.inbox_id"
              :options="inboxOptions"
              :aria-label="t('AI_ANALYTICS.INBOX')"
              class="mt-1 [&_select]:min-h-11"
              data-test="inbox-select"
              @update:model-value="load"
            />
          </label>
          <div class="flex flex-col gap-1 text-xs tabular-nums text-n-slate-11">
            <span v-if="data?.filters?.timezone" data-test="timezone">{{
              t('GENERAL_DASHBOARD.TIMEZONE', { zone: data.filters.timezone })
            }}</span>
            <span v-if="updatedText" data-test="updated-at">{{
              updatedText
            }}</span>
          </div>
        </div>
      </header>

      <div
        v-if="filters.period === 'custom'"
        class="flex shrink-0 flex-wrap items-end gap-3"
        data-test="custom-range"
      >
        <label class="text-xs text-n-slate-11">
          {{ t('AI_ANALYTICS.START') }}
          <input
            v-model="start"
            type="date"
            :max="end || undefined"
            class="!mb-0 mt-1 min-h-11 !w-auto"
          />
        </label>
        <label class="text-xs text-n-slate-11">
          {{ t('AI_ANALYTICS.END') }}
          <input
            v-model="end"
            type="date"
            :min="start || undefined"
            class="!mb-0 mt-1 min-h-11 !w-auto"
          />
        </label>
        <button
          type="button"
          class="min-h-11 rounded-lg bg-n-blue-9 px-4 text-sm text-white disabled:opacity-50"
          :disabled="!start || !end || start > end"
          @click="load"
        >
          {{ t('AI_ANALYTICS.APPLY') }}
        </button>
      </div>

      <section
        class="grid shrink-0 grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4"
        :aria-label="t('GENERAL_DASHBOARD.TITLE')"
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
          :spark-label="kpi.sparkLabel"
          :loading="loading"
          :data-test="`kpi-${kpi.key}`"
        />
      </section>

      <div class="flex flex-wrap gap-4">
        <AnalyticsCard
          class="min-w-0 flex-[2_1_30rem]"
          :title="t('GENERAL_DASHBOARD.REPLIES_PER_DAY')"
          :info="t('GENERAL_DASHBOARD.REPLIES_INFO')"
          :period="periodCaption"
          :loading="loading"
          :error="failed"
          :empty="!repliesTotal"
          :empty-text="t('GENERAL_DASHBOARD.REPLIES_EMPTY')"
          data-test="replies-card"
          @retry="load"
        >
          <template #actions>
            <RouterLink
              :to="{ name: 'conversation_reports', params: { accountId } }"
              class="text-sm text-n-slate-11 underline hover:text-n-slate-12"
              data-test="full-report"
            >
              {{ t('GENERAL_DASHBOARD.FULL_REPORT') }}
            </RouterLink>
          </template>
          <RepliesChart
            :days="attendance?.replies?.per_day || []"
            :ai-label="t('CRM.RESPONDER_REPORT.LEGEND_AI')"
            :people-label="t('CRM.RESPONDER_REPORT.LEGEND_HUMAN')"
            :aria-label="t('GENERAL_DASHBOARD.REPLIES_ARIA')"
            :locale="locale"
          />
          <ul
            class="m-0 flex list-none flex-wrap gap-x-5 gap-y-1.5 p-0 text-xs text-n-slate-11"
            data-test="replies-legend"
          >
            <li
              v-for="item in replyLegend"
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
                {{ itemTotals(item) }}
              </strong>
            </li>
          </ul>
        </AnalyticsCard>
        <WaitingCard
          class="min-w-0 flex-[1_1_20rem]"
          :waiting="attendance?.waiting"
          :locale="locale"
          :loading="loading"
          :error="failed"
          @retry="load"
        />
      </div>

      <div class="flex flex-wrap gap-4">
        <HeatmapCard
          class="min-w-0 flex-[1_1_26rem]"
          :heatmap="attendance?.heatmap || []"
          :period="periodCaption"
          :locale="locale"
          :loading="loading"
          :error="failed"
          @retry="load"
        />
        <AiCard
          class="min-w-0 flex-[1_1_30rem]"
          :ai="ai"
          :attendance="attendance"
          :period="periodCaption"
          :locale="locale"
          :loading="loading"
          :error="failed"
          @retry="load"
        />
      </div>

      <div class="flex flex-wrap gap-4">
        <TeamCard
          class="min-w-0 flex-[1_1_28rem]"
          :agents="attendance?.agents || []"
          :period="periodCaption"
          :locale="locale"
          :loading="loading"
          :error="failed"
          @retry="load"
        />
        <CrmCard
          class="min-w-0 flex-[1_1_28rem]"
          :crm="crm"
          :period="periodCaption"
          :locale="locale"
          :loading="loading"
          :error="failed"
          @retry="load"
          @pipeline="choosePipeline"
        />
      </div>

      <BlastsCard
        :blasts="blasts"
        :period="periodCaption"
        :locale="locale"
        :loading="loading"
        :error="failed"
        @retry="load"
      />
    </div>
  </main>
</template>
