<script setup>
import { computed, ref } from 'vue';
import { useElementSize } from '@vueuse/core';
import {
  integerTicks,
  labelIndexes,
} from '../../settings/aiAnalytics/chartGeometry';
import {
  formatDate,
  formatDayMonth,
  formatNumber,
} from '../../settings/aiAnalytics/analyticsFormat';

// Replies per day, the AI at the bottom of each bar and people on top, so the size of the day is as visible as the split.
// `days`: [{ date, ai, people }]
const props = defineProps({
  days: { type: Array, required: true },
  aiLabel: { type: String, required: true },
  peopleLabel: { type: String, required: true },
  ariaLabel: { type: String, required: true },
  locale: { type: String, default: 'pt-BR' },
});

const HEIGHT = 230;
const MARGIN = { top: 26, right: 8, bottom: 30, left: 38 };
const MIN_SLOT = 26;

const container = ref(null);
const { width: measured } = useElementSize(container);
const width = computed(() =>
  Math.max(measured.value || 560, props.days.length * MIN_SLOT + MARGIN.left)
);
const plotWidth = computed(() => width.value - MARGIN.left - MARGIN.right);
const plotHeight = HEIGHT - MARGIN.top - MARGIN.bottom;
const baseline = MARGIN.top + plotHeight;

const totals = computed(() => props.days.map(day => day.ai + day.people));
const highest = computed(() => Math.max(0, ...totals.value));
const scale = computed(() => integerTicks(highest.value));
const slot = computed(() => plotWidth.value / Math.max(1, props.days.length));
const barWidth = computed(() => Math.max(6, Math.min(44, slot.value * 0.62)));
const y = value => baseline - (value / scale.value.max) * plotHeight;

const bars = computed(() =>
  props.days.map((day, index) => {
    const x =
      MARGIN.left + slot.value * index + (slot.value - barWidth.value) / 2;
    const total = day.ai + day.people;
    return {
      date: day.date,
      x,
      center: x + barWidth.value / 2,
      aiY: y(day.ai),
      aiHeight: baseline - y(day.ai),
      peopleY: y(total),
      peopleHeight: y(day.ai) - y(total),
      total,
      isPeak: total > 0 && total === highest.value,
      title: `${formatDate(day.date, props.locale)}: ${props.aiLabel} ${formatNumber(day.ai, props.locale)}, ${props.peopleLabel} ${formatNumber(day.people, props.locale)}`,
    };
  })
);
const yTicks = computed(() =>
  scale.value.ticks.map(value => ({ value, y: y(value) }))
);
const xLabels = computed(() =>
  labelIndexes(props.days.length, plotWidth.value, 56).map(index => ({
    index,
    x: bars.value[index].center,
    text: formatDayMonth(props.days[index].date, props.locale),
  }))
);
// Every total fits above its bar while the days are few; with many days only the busiest is written.
const showTotal = bar =>
  bar.total > 0 && (props.days.length <= 14 || bar.isPeak);
</script>

<template>
  <div
    ref="container"
    role="region"
    tabindex="0"
    :aria-label="ariaLabel"
    class="overflow-x-auto overflow-y-hidden rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
    data-test="replies-scroll"
  >
    <svg
      role="img"
      :aria-label="ariaLabel"
      :width="width"
      :height="HEIGHT"
      :viewBox="`0 0 ${width} ${HEIGHT}`"
      class="block"
      data-test="replies-chart"
    >
      <g aria-hidden="true">
        <g v-for="tick in yTicks" :key="tick.value">
          <line
            :x1="MARGIN.left"
            :x2="width - MARGIN.right"
            :y1="tick.y"
            :y2="tick.y"
            class="stroke-n-slate-5"
            stroke-width="1"
          />
          <text
            :x="MARGIN.left - 8"
            :y="tick.y + 4"
            text-anchor="end"
            class="fill-n-slate-11 text-xs tabular-nums"
          >
            {{ formatNumber(tick.value, locale) }}
          </text>
        </g>
      </g>
      <g v-for="bar in bars" :key="bar.date" data-test="reply-bar">
        <title>{{ bar.title }}</title>
        <rect
          v-if="bar.aiHeight > 0"
          :x="bar.x"
          :y="bar.aiY"
          :width="barWidth"
          :height="bar.aiHeight"
          fill="var(--an-ai)"
          data-test="ai-segment"
        />
        <rect
          v-if="bar.peopleHeight > 0"
          :x="bar.x"
          :y="bar.peopleY"
          :width="barWidth"
          :height="bar.peopleHeight"
          rx="3"
          fill="var(--an-people)"
          data-test="people-segment"
        />
        <text
          v-if="showTotal(bar)"
          :x="bar.center"
          :y="bar.peopleY - 6"
          text-anchor="middle"
          class="text-xs tabular-nums"
          :class="
            bar.isPeak ? 'fill-n-slate-12 font-semibold' : 'fill-n-slate-11'
          "
          aria-hidden="true"
          data-test="bar-total"
        >
          {{ formatNumber(bar.total, locale) }}
        </text>
      </g>
      <g aria-hidden="true">
        <text
          v-for="label in xLabels"
          :key="label.index"
          :x="label.x"
          :y="HEIGHT - 8"
          text-anchor="middle"
          class="fill-n-slate-11 text-xs tabular-nums"
        >
          {{ label.text }}
        </text>
      </g>
    </svg>
  </div>
</template>
