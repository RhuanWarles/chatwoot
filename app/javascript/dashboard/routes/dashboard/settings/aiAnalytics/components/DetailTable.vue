<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { EMPTY, formatDate, formatNumber } from '../analyticsFormat';
import { peakOf } from '../analyticsMetrics';
import AnalyticsCard from './AnalyticsCard.vue';

// Day by day, the most recent first. A day with nothing in it is grey with dashes; the busiest day carries a "peak" tag;
// the last row is the total of the period, where conversations are counted once (a conversation can span several days).
const props = defineProps({
  timeseries: { type: Array, default: () => [] },
  summary: { type: Object, default: null },
  billing: { type: Object, default: null },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();

const withCredits = computed(() => props.billing?.mode === 'platform');
const peakDate = computed(() => peakOf(props.timeseries, 'messages')?.date);
const mostTokens = computed(() =>
  Math.max(0, ...props.timeseries.map(day => Number(day.tokens || 0)))
);
const hasActivity = day =>
  [day.conversations, day.turns, day.messages, day.tokens, day.credits].some(
    value => Number(value) > 0
  );
const rows = computed(() =>
  [...props.timeseries].reverse().map(day => ({
    ...day,
    active: hasActivity(day),
    peak: day.date === peakDate.value,
    tokenShare: mostTokens.value
      ? (Number(day.tokens || 0) / mostTokens.value) * 100
      : 0,
  }))
);
const count = (value, active) =>
  active ? formatNumber(value, props.locale) : EMPTY;
const columns = computed(() => [
  { key: 'date', label: t('AI_ANALYTICS.DATE'), end: false },
  { key: 'conversations', label: t('AI_ANALYTICS.CONVERSATIONS'), end: true },
  { key: 'turns', label: t('AI_ANALYTICS.TURNS'), end: true },
  { key: 'messages', label: t('AI_ANALYTICS.MESSAGES'), end: true },
  { key: 'tokens', label: t('AI_ANALYTICS.TOKENS'), end: true },
  ...(withCredits.value
    ? [{ key: 'credits', label: t('AI_ANALYTICS.CREDITS_USED'), end: true }]
    : []),
]);
</script>

<template>
  <AnalyticsCard
    :title="t('AI_ANALYTICS.DETAILS')"
    :info="t('AI_ANALYTICS.DETAILS_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    :empty="!timeseries.length"
    :empty-text="t('AI_ANALYTICS.EMPTY')"
    data-test="detail-card"
    @retry="$emit('retry')"
  >
    <div
      role="region"
      tabindex="0"
      :aria-label="t('AI_ANALYTICS.DETAILS_SCROLL')"
      class="max-h-[34rem] overflow-auto rounded-lg border border-n-weak outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      data-test="detail-scroll"
    >
      <table class="w-full min-w-[34rem] border-collapse text-sm tabular-nums">
        <caption class="sr-only">
          {{
            t('AI_ANALYTICS.DETAILS')
          }}
        </caption>
        <thead class="sticky top-0 z-10 bg-n-solid-2 text-n-slate-11">
          <tr>
            <th
              v-for="column in columns"
              :key="column.key"
              scope="col"
              class="px-3 py-2.5 text-xs font-medium"
              :class="column.end ? 'text-end' : 'text-start'"
            >
              {{ column.label }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.date"
            class="border-t border-n-weak"
            :class="row.active ? 'text-n-slate-12' : 'text-n-slate-10'"
            data-test="detail-row"
            :data-active="row.active"
          >
            <th
              scope="row"
              class="whitespace-nowrap px-3 py-2 text-start font-normal"
            >
              {{ formatDate(row.date, locale) }}
              <span
                v-if="row.peak"
                class="ms-2 rounded bg-n-alpha-2 px-1.5 py-0.5 text-xs font-medium text-n-slate-12"
                data-test="peak-tag"
                >{{ t('AI_ANALYTICS.PEAK_TAG') }}</span
              >
            </th>
            <td class="px-3 py-2 text-end">
              {{ count(row.conversations, row.active) }}
            </td>
            <td class="px-3 py-2 text-end">
              {{ count(row.turns, row.active) }}
            </td>
            <td class="px-3 py-2 text-end">
              {{ count(row.messages, row.active) }}
            </td>
            <td class="px-3 py-2 text-end">
              <span class="inline-flex items-center justify-end gap-2">
                <span
                  v-if="row.tokenShare"
                  class="hidden h-1.5 w-16 overflow-hidden rounded-full bg-n-alpha-3 sm:inline-block"
                  aria-hidden="true"
                >
                  <span
                    class="block h-full rounded-full bg-[var(--an-tokens)]"
                    :style="{ width: `${row.tokenShare}%` }"
                  />
                </span>
                {{ count(row.tokens, row.active) }}
              </span>
            </td>
            <td v-if="withCredits" class="px-3 py-2 text-end">
              {{ count(row.credits, row.active) }}
            </td>
          </tr>
        </tbody>
        <tfoot
          class="sticky bottom-0 bg-n-solid-2 font-semibold text-n-slate-12"
        >
          <tr class="border-t border-n-weak" data-test="total-row">
            <th scope="row" class="px-3 py-2.5 text-start font-semibold">
              {{ t('AI_ANALYTICS.TOTAL') }}
            </th>
            <td class="px-3 py-2.5 text-end" data-test="total-conversations">
              {{ formatNumber(summary?.conversations, locale) }}*
            </td>
            <td class="px-3 py-2.5 text-end">
              {{ formatNumber(summary?.turns, locale) }}
            </td>
            <td class="px-3 py-2.5 text-end">
              {{ formatNumber(summary?.messages, locale) }}
            </td>
            <td class="px-3 py-2.5 text-end">
              {{ formatNumber(billing?.total_tokens, locale) }}
            </td>
            <td v-if="withCredits" class="px-3 py-2.5 text-end">
              {{ formatNumber(billing?.credits_consumed, locale) }}
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
    <p class="m-0 text-xs text-n-slate-11" data-test="total-note">
      {{ t('AI_ANALYTICS.TOTAL_NOTE') }}
    </p>
  </AnalyticsCard>
</template>
