<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatNumber, formatPercent } from '../analyticsFormat';
import AnalyticsCard from './AnalyticsCard.vue';
import InfoTip from './InfoTip.vue';
import StatTile from './StatTile.vue';

// How the tools of the AI ran: the totals and, per tool, how many times it ran and how often it worked.
const props = defineProps({
  tools: { type: Object, default: null },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();

const executions = computed(() => Number(props.tools?.executions || 0));
const list = computed(() =>
  [...(props.tools?.top || [])].sort((a, b) => b.executions - a.executions)
);
const most = computed(() =>
  Math.max(1, ...list.value.map(tool => tool.executions))
);
const count = value => formatNumber(value, props.locale);
// Green and red only when there is something to be green or red about.
const tone = (value, color) => (Number(value) > 0 ? color : 'muted');
const showEmptyLine = computed(
  () => !props.loading && !props.error && props.tools && !executions.value
);
</script>

<template>
  <section
    v-if="showEmptyLine"
    class="flex min-w-0 flex-wrap items-center justify-between gap-x-4 gap-y-1 self-start rounded-xl border border-n-weak bg-n-solid-1 px-4 py-3 sm:px-5"
    data-test="tools-empty"
  >
    <h2
      class="m-0 flex items-center gap-1.5 text-sm font-semibold text-n-slate-12"
    >
      {{ t('AI_ANALYTICS.TOOLS') }}
      <InfoTip :text="t('AI_ANALYTICS.TOOLS_INFO')" />
    </h2>
    <p class="m-0 text-sm text-n-slate-11">
      {{ t('AI_ANALYTICS.EMPTY_TOOLS') }}
      <span class="text-xs">· {{ period }}</span>
    </p>
  </section>

  <AnalyticsCard
    v-else
    :title="t('AI_ANALYTICS.TOOLS')"
    :info="t('AI_ANALYTICS.TOOLS_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    data-test="tools-card"
    @retry="$emit('retry')"
  >
    <dl class="m-0 grid grid-cols-2 gap-3 sm:grid-cols-4">
      <StatTile
        :label="t('AI_ANALYTICS.EXECUTIONS')"
        :value="count(tools?.executions)"
      />
      <StatTile
        :label="t('AI_ANALYTICS.SUCCESS')"
        :value="count(tools?.success)"
        :tone="tone(tools?.success, 'good')"
        data-test="tile-success"
      />
      <StatTile
        :label="t('AI_ANALYTICS.FAILURES')"
        :value="count(tools?.failures)"
        :tone="tone(tools?.failures, 'bad')"
        data-test="tile-failures"
      />
      <StatTile
        :label="t('AI_ANALYTICS.SUCCESS_RATE')"
        :value="formatPercent(executions ? tools?.success_rate : null, locale)"
        data-test="tile-success-rate"
      />
    </dl>

    <ul class="m-0 flex list-none flex-col gap-3 p-0" data-test="tool-list">
      <li
        v-for="tool in list"
        :key="tool.id"
        class="flex flex-col gap-1.5 sm:grid sm:grid-cols-[minmax(6rem,12rem)_minmax(0,1fr)_auto_3.5rem] sm:items-center sm:gap-3"
        data-test="tool-row"
      >
        <div class="flex items-center justify-between gap-3 sm:contents">
          <span
            class="truncate font-mono text-xs text-n-slate-12"
            :title="tool.name"
          >
            {{ tool.name }}
          </span>
          <span class="shrink-0 text-xs tabular-nums text-n-slate-11 sm:hidden">
            <strong class="font-semibold text-n-slate-12">{{
              count(tool.executions)
            }}</strong>
            · {{ formatPercent(tool.success_rate, locale, 0) }}
          </span>
        </div>
        <span
          class="h-2 overflow-hidden rounded-full bg-n-alpha-3"
          aria-hidden="true"
        >
          <span
            class="block h-full rounded-full bg-[var(--an-ai)]"
            :style="{ width: `${(tool.executions / most) * 100}%` }"
          />
        </span>
        <span
          class="hidden text-end text-xs font-semibold tabular-nums text-n-slate-12 sm:inline"
        >
          {{ count(tool.executions) }}
        </span>
        <span
          class="hidden text-end text-xs tabular-nums text-n-slate-11 sm:inline"
        >
          {{ formatPercent(tool.success_rate, locale, 0) }}
        </span>
      </li>
    </ul>
  </AnalyticsCard>
</template>
