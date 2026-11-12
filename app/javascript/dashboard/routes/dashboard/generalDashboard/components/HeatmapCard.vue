<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatNumber } from '../../settings/aiAnalytics/analyticsFormat';
import AnalyticsCard from '../../settings/aiAnalytics/components/AnalyticsCard.vue';
import { heatLevel, heatmapMax } from '../dashboardMetrics';

// When customers write: new conversations by weekday (Monday first) and hour of the account's clock.
const props = defineProps({
  heatmap: { type: Array, default: () => [] },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();

const total = computed(() =>
  props.heatmap.reduce((sum, row) => sum + row.reduce((a, b) => a + b, 0), 0)
);
const highest = computed(() => heatmapMax(props.heatmap));
// 2024-01-01 was a Monday.
const weekdays = computed(() =>
  Array.from({ length: 7 }, (_, index) =>
    new Intl.DateTimeFormat(props.locale, {
      weekday: 'short',
      timeZone: 'UTC',
    })
      .format(new Date(Date.UTC(2024, 0, 1 + index)))
      .replace('.', '')
  )
);
const rows = computed(() =>
  props.heatmap.map((row, day) => ({
    day: weekdays.value[day],
    cells: row.map((count, hour) => ({
      hour,
      background: count
        ? `color-mix(in srgb, var(--an-conversations) ${Math.round(12 + heatLevel(count, highest.value) * 78)}%, transparent)`
        : 'transparent',
      title: t('GENERAL_DASHBOARD.HEATMAP_CELL', {
        day: weekdays.value[day],
        hour,
        count: formatNumber(count, props.locale),
      }),
    })),
  }))
);
const hourMarks = [0, 6, 12, 18, 23];
</script>

<template>
  <AnalyticsCard
    :title="t('GENERAL_DASHBOARD.HEATMAP')"
    :info="t('GENERAL_DASHBOARD.HEATMAP_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    :empty="!total"
    data-test="heatmap-card"
    @retry="$emit('retry')"
  >
    <div
      role="img"
      :aria-label="
        t('GENERAL_DASHBOARD.HEATMAP_ARIA', {
          count: formatNumber(total, locale),
        })
      "
      class="flex flex-col gap-1"
    >
      <div
        v-for="row in rows"
        :key="row.day"
        class="flex items-center gap-2"
        data-test="heatmap-row"
      >
        <span class="w-9 shrink-0 text-xs capitalize text-n-slate-11">{{
          row.day
        }}</span>
        <div
          class="grid min-w-0 flex-1 grid-cols-[repeat(24,minmax(0,1fr))] gap-0.5"
        >
          <span
            v-for="cell in row.cells"
            :key="cell.hour"
            :title="cell.title"
            class="h-5 rounded-sm border border-n-weak"
            :style="{ background: cell.background }"
            data-test="heatmap-cell"
          />
        </div>
      </div>
      <div class="flex items-center gap-2" aria-hidden="true">
        <span class="w-9 shrink-0" />
        <div class="relative h-4 flex-1">
          <span
            v-for="hour in hourMarks"
            :key="hour"
            class="absolute text-xs tabular-nums text-n-slate-11"
            :style="{ left: `${(hour / 24) * 100}%` }"
            >{{ t('GENERAL_DASHBOARD.HOUR_MARK', { hour }) }}</span
          >
        </div>
      </div>
    </div>
  </AnalyticsCard>
</template>
