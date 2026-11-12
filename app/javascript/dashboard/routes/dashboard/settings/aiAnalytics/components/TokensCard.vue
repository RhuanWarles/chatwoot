<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  EMPTY,
  formatCompact,
  formatNumber,
  formatPercent,
  formatUsd,
} from '../analyticsFormat';
import { percentOf, ratio, tokensPerTurn } from '../analyticsMetrics';
import { estimateCost, pricedModels } from '../modelPricing';
import AnalyticsCard from './AnalyticsCard.vue';
import ColumnBars from './ColumnBars.vue';
import StatTile from './StatTile.vue';

// Tokens the AI used, what they cost (an estimate from the list price of the model) and how they are spread over the days.
const props = defineProps({
  billing: { type: Object, default: null },
  summary: { type: Object, default: null },
  timeseries: { type: Array, default: () => [] },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();

const money = value => formatUsd(value, props.locale);
const input = computed(() => Number(props.billing?.prompt_tokens || 0));
const output = computed(() => Number(props.billing?.completion_tokens || 0));
const used = computed(() => input.value + output.value);
const cost = computed(() => estimateCost(props.billing?.models));
const perConversation = computed(() =>
  ratio(cost.value, props.summary?.conversations)
);
const costInfo = computed(() => {
  const priced = pricedModels(props.billing?.models);
  if (cost.value == null || !priced.length) {
    return t('AI_ANALYTICS.COST_INFO_NO_PRICE');
  }
  const prices = priced
    .map(item =>
      t('AI_ANALYTICS.COST_PRICE', {
        model: item.model,
        input: money(item.input),
        output: money(item.output),
      })
    )
    .join('; ');
  return t('AI_ANALYTICS.COST_INFO', { prices });
});
const tokenValue = value =>
  used.value ? formatNumber(value, props.locale) : EMPTY;
const share = value =>
  formatPercent(percentOf(value, used.value), props.locale);

const tiles = computed(() => [
  {
    key: 'input',
    label: t('AI_ANALYTICS.INPUT_TOKENS'),
    value: tokenValue(input.value),
    sub: used.value
      ? t('AI_ANALYTICS.OF_TOTAL', { share: share(input.value) })
      : '',
  },
  {
    key: 'output',
    label: t('AI_ANALYTICS.OUTPUT_TOKENS'),
    value: tokenValue(output.value),
    sub: used.value
      ? t('AI_ANALYTICS.OF_TOTAL', { share: share(output.value) })
      : '',
  },
  {
    key: 'cost',
    label: t('AI_ANALYTICS.ESTIMATED_COST'),
    value: money(cost.value),
    info: costInfo.value,
  },
  {
    key: 'cost-per-conversation',
    label: t('AI_ANALYTICS.COST_AVERAGE'),
    value: money(perConversation.value),
    info: costInfo.value,
  },
]);
const credits = computed(() =>
  props.billing?.mode === 'platform'
    ? [
        {
          key: 'credits-used',
          label: t('AI_ANALYTICS.CREDITS_USED'),
          value: formatNumber(props.billing.credits_consumed, props.locale, 2),
        },
        {
          key: 'credits-average',
          label: t('AI_ANALYTICS.CREDITS_AVERAGE'),
          value: formatNumber(
            props.billing.average_credits_per_conversation,
            props.locale,
            2
          ),
          info: t('AI_ANALYTICS.CREDITS_HELP'),
        },
        {
          key: 'credits-available',
          label: t('AI_ANALYTICS.CREDITS_AVAILABLE'),
          value: formatNumber(props.billing.credits_available, props.locale, 2),
        },
      ]
    : []
);

const days = computed(() =>
  props.timeseries.map(day => ({ date: day.date, value: day.tokens }))
);
const perTurn = computed(() =>
  tokensPerTurn(props.billing, props.summary?.turns)
);
const callout = computed(() =>
  perTurn.value.input && perTurn.value.output
    ? t('AI_ANALYTICS.TOKENS_CALLOUT', {
        input: formatCompact(perTurn.value.input, props.locale),
        output: formatCompact(perTurn.value.output, props.locale),
      })
    : ''
);
</script>

<template>
  <AnalyticsCard
    :title="t('AI_ANALYTICS.CONSUMPTION')"
    :info="t('AI_ANALYTICS.CONSUMPTION_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    :empty="!summary?.turns"
    data-test="tokens-card"
    @retry="$emit('retry')"
  >
    <dl class="m-0 grid grid-cols-2 gap-3 xl:grid-cols-4">
      <StatTile
        v-for="tile in tiles"
        :key="tile.key"
        :label="tile.label"
        :value="tile.value"
        :sub="tile.sub"
        :info="tile.info"
        :tone="tile.value === EMPTY ? 'muted' : 'neutral'"
        :data-test="`tile-${tile.key}`"
      />
    </dl>
    <dl
      v-if="credits.length"
      class="m-0 grid grid-cols-1 gap-3 sm:grid-cols-3"
      data-test="credit-tiles"
    >
      <StatTile
        v-for="tile in credits"
        :key="tile.key"
        :label="tile.label"
        :value="tile.value"
        :info="tile.info"
      />
    </dl>

    <div>
      <h3 class="m-0 mb-2 text-xs font-medium text-n-slate-11">
        {{ t('AI_ANALYTICS.TOKENS_PER_DAY') }}
      </h3>
      <ColumnBars
        :points="days"
        color="var(--an-tokens)"
        :aria-label="t('AI_ANALYTICS.TOKENS_PER_DAY_ARIA')"
        :value-label="t('AI_ANALYTICS.TOKENS_UNIT')"
        :locale="locale"
      />
    </div>

    <p
      v-if="callout"
      class="m-0 rounded-lg bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12"
      data-test="tokens-callout"
    >
      {{ callout }}
    </p>
  </AnalyticsCard>
</template>
