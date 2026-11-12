<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  formatDayMonth,
  formatDuration,
  formatNumber,
  formatPercent,
} from '../analyticsFormat';
import { outcomeOf, peakOf, ratio } from '../analyticsMetrics';
import AnalyticsCard from './AnalyticsCard.vue';
import InfoTip from './InfoTip.vue';
import ShareBar from './ShareBar.vue';

// What happened to the conversations the AI handled (kept by the AI or handed off) and the numbers of the operation.
const props = defineProps({
  summary: { type: Object, default: null },
  timeseries: { type: Array, default: () => [] },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();

const outcome = computed(() => outcomeOf(props.summary || {}));
const segments = computed(() => [
  {
    key: 'kept',
    label: t('AI_ANALYTICS.OUTCOME_KEPT'),
    value: outcome.value.kept,
    color: 'var(--an-ai)',
  },
  {
    key: 'handoff',
    label: t('AI_ANALYTICS.OUTCOME_HANDOFF'),
    value: outcome.value.handoffs,
    color: 'var(--an-people)',
  },
]);
const busiest = computed(() => {
  const peak = peakOf(props.timeseries, 'conversations');
  return peak
    ? t('AI_ANALYTICS.BUSIEST_DAY_VALUE', {
        date: formatDayMonth(peak.date, props.locale),
        count: t(
          'AI_ANALYTICS.CONVERSATIONS_COUNT',
          { n: formatNumber(peak.value, props.locale) },
          peak.value
        ),
      })
    : '—';
});
const responseTime = computed(() => props.summary?.average_response_ms);
// The response time is not measured yet (the API sends nothing), so the line stays out until there is a number to show.
const rows = computed(() => [
  {
    key: 'turns',
    label: t('AI_ANALYTICS.TURNS'),
    info: t('AI_ANALYTICS.TURNS_HELP'),
    value: formatNumber(props.summary?.turns, props.locale),
  },
  {
    key: 'turns-per-conversation',
    label: t('AI_ANALYTICS.TURNS_PER_CONVERSATION'),
    info: t('AI_ANALYTICS.TURNS_PER_CONVERSATION_INFO'),
    value: formatNumber(
      ratio(props.summary?.turns, outcome.value.conversations),
      props.locale,
      1
    ),
  },
  {
    key: 'handoff-rate',
    label: t('AI_ANALYTICS.HANDOFF_RATE'),
    info: t('AI_ANALYTICS.HANDOFF_RATE_INFO'),
    value: formatPercent(outcome.value.handoffShare, props.locale),
  },
  {
    key: 'busiest',
    label: t('AI_ANALYTICS.BUSIEST_DAY'),
    value: busiest.value,
  },
  ...(responseTime.value == null
    ? []
    : [
        {
          key: 'response-time',
          label: t('AI_ANALYTICS.RESPONSE_TIME'),
          value: formatDuration(responseTime.value, props.locale),
        },
      ]),
]);
</script>

<template>
  <AnalyticsCard
    :title="t('AI_ANALYTICS.OUTCOME')"
    :info="t('AI_ANALYTICS.OUTCOME_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    :empty="!outcome.conversations"
    data-test="outcome-card"
    @retry="$emit('retry')"
  >
    <ShareBar
      :segments="segments"
      :locale="locale"
      :aria-label="t('AI_ANALYTICS.OUTCOME_ARIA')"
    />
    <div class="border-t border-n-weak pt-3">
      <h3 class="m-0 text-xs font-medium text-n-slate-11">
        {{ t('AI_ANALYTICS.OPERATION') }}
      </h3>
      <dl class="m-0 mt-2 flex flex-col">
        <div
          v-for="row in rows"
          :key="row.key"
          class="flex items-center justify-between gap-3 border-b border-n-weak py-2 text-sm last:border-b-0"
          :data-test="`operation-${row.key}`"
        >
          <dt class="flex min-w-0 items-center gap-1 text-n-slate-11">
            {{ row.label }}
            <InfoTip v-if="row.info" :text="row.info" />
          </dt>
          <dd class="m-0 shrink-0 font-semibold tabular-nums text-n-slate-12">
            {{ row.value }}
          </dd>
        </div>
      </dl>
    </div>
  </AnalyticsCard>
</template>
