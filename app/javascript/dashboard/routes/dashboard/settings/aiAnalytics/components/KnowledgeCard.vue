<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatNumber, formatPercent } from '../analyticsFormat';
import { percentOf } from '../analyticsMetrics';
import AnalyticsCard from './AnalyticsCard.vue';
import ShareBar from './ShareBar.vue';
import StatTile from './StatTile.vue';

// The questions the AI asked the knowledge bases: how many found something, how many conversations used the bases and
// which questions found nothing (the ones worth writing a document for).
const props = defineProps({
  knowledge: { type: Object, default: null },
  summary: { type: Object, default: null },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();

const queries = computed(() => Number(props.knowledge?.queries || 0));
const hits = computed(() => Number(props.knowledge?.hits || 0));
const misses = computed(() => Math.max(0, queries.value - hits.value));
const segments = computed(() => [
  {
    key: 'hits',
    label: t('AI_ANALYTICS.KNOWLEDGE_WITH_RESULT'),
    value: hits.value,
    color: 'var(--an-neutral)',
  },
  {
    key: 'misses',
    label: t('AI_ANALYTICS.KNOWLEDGE_NO_RESULT'),
    value: misses.value,
    color: 'var(--an-attention)',
  },
]);
const handled = computed(() => Number(props.summary?.conversations || 0));
const used = computed(() => Number(props.knowledge?.conversations || 0));
const unanswered = computed(() => props.knowledge?.unanswered || []);
</script>

<template>
  <AnalyticsCard
    :title="t('AI_ANALYTICS.KNOWLEDGE')"
    :info="t('AI_ANALYTICS.KNOWLEDGE_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    :empty="!queries"
    :empty-text="t('AI_ANALYTICS.EMPTY_KNOWLEDGE')"
    data-test="knowledge-card"
    @retry="$emit('retry')"
  >
    <div>
      <p class="m-0 mb-2 text-xs tabular-nums text-n-slate-11">
        {{
          t(
            'AI_ANALYTICS.KNOWLEDGE_QUERIES',
            { n: formatNumber(queries, locale) },
            queries
          )
        }}
        · {{ t('AI_ANALYTICS.HIT_RATE') }}
        {{ formatPercent(percentOf(hits, queries), locale) }}
      </p>
      <ShareBar
        :segments="segments"
        :locale="locale"
        :aria-label="t('AI_ANALYTICS.KNOWLEDGE_BAR_ARIA')"
      />
    </div>

    <dl class="m-0 grid grid-cols-1 gap-3 sm:grid-cols-2">
      <StatTile
        :label="t('AI_ANALYTICS.KNOWLEDGE_CONVERSATIONS')"
        :value="
          t('AI_ANALYTICS.KNOWLEDGE_USED_OF', {
            used: formatNumber(used, locale),
            total: formatNumber(handled, locale),
          })
        "
        data-test="tile-used"
      />
      <StatTile
        :label="t('AI_ANALYTICS.UTILIZATION')"
        :info="t('AI_ANALYTICS.UTILIZATION_HELP')"
        :value="
          formatPercent(handled ? knowledge?.utilization_rate : null, locale)
        "
        data-test="tile-utilization"
      />
    </dl>

    <div class="border-t border-n-weak pt-3">
      <h3 class="m-0 text-xs font-medium text-n-slate-11">
        {{
          t('AI_ANALYTICS.UNANSWERED', { count: formatNumber(misses, locale) })
        }}
      </h3>
      <p
        v-if="!misses"
        class="m-0 mt-2 text-sm text-n-slate-11"
        data-test="unanswered-empty"
      >
        {{ t('AI_ANALYTICS.UNANSWERED_EMPTY') }}
      </p>
      <ol
        v-else-if="unanswered.length"
        class="m-0 mt-2 flex list-none flex-col p-0"
        data-test="unanswered-list"
      >
        <li
          v-for="item in unanswered"
          :key="item.query"
          class="flex items-start justify-between gap-3 border-b border-n-weak py-2 text-sm last:border-b-0"
        >
          <span class="min-w-0 break-words text-n-slate-12">{{
            item.query
          }}</span>
          <span class="shrink-0 tabular-nums text-n-slate-11">{{
            t('AI_ANALYTICS.UNANSWERED_TIMES', {
              count: formatNumber(item.count, locale),
            })
          }}</span>
        </li>
      </ol>
    </div>
  </AnalyticsCard>
</template>
