<script setup>
import { computed, ref } from 'vue';
import { useElementSize } from '@vueuse/core';
import { labelIndexes } from '../chartGeometry';
import {
  formatCompact,
  formatDate,
  formatDayMonth,
  formatNumber,
} from '../analyticsFormat';
import { peakOf } from '../analyticsMetrics';

// One column per day. The busiest day is at full strength and carries its value; the others are softer so the eye goes
// to the peak. A day with nothing in it is a dashed tick, not an empty space that looks like missing data.
// `points`: [{ date, value }]
const props = defineProps({
  points: { type: Array, required: true },
  color: { type: String, required: true },
  ariaLabel: { type: String, required: true },
  valueLabel: { type: String, required: true },
  locale: { type: String, default: 'pt-BR' },
});

const HEIGHT = 190;
const MARGIN = { top: 24, right: 4, bottom: 28, left: 4 };
const MIN_BAR_SLOT = 9;

const container = ref(null);
const { width: measured } = useElementSize(container);
const width = computed(() =>
  Math.max(measured.value || 480, props.points.length * MIN_BAR_SLOT)
);
const plotWidth = computed(() => width.value - MARGIN.left - MARGIN.right);
const plotHeight = HEIGHT - MARGIN.top - MARGIN.bottom;
const baseline = MARGIN.top + plotHeight;

const peak = computed(() => peakOf(props.points, 'value'));
const slot = computed(() => plotWidth.value / Math.max(1, props.points.length));
const barWidth = computed(() => Math.max(4, Math.min(28, slot.value * 0.64)));
const hovered = ref(null);

const bars = computed(() =>
  props.points.map((point, index) => {
    const value = Number(point.value || 0);
    const height = peak.value ? (value / peak.value.value) * plotHeight : 0;
    return {
      index,
      value,
      x: MARGIN.left + slot.value * index + (slot.value - barWidth.value) / 2,
      y: baseline - height,
      height,
      isPeak: peak.value?.index === index,
      title: `${formatDate(point.date, props.locale)}: ${formatNumber(value, props.locale)} ${props.valueLabel}`,
    };
  })
);
const xLabels = computed(() =>
  labelIndexes(props.points.length, plotWidth.value, 56).map(index => ({
    index,
    x: MARGIN.left + slot.value * index + slot.value / 2,
    text: formatDayMonth(props.points[index].date, props.locale),
  }))
);
const marked = computed(() =>
  bars.value.filter(
    bar => bar.value > 0 && (bar.isPeak || bar.index === hovered.value)
  )
);
</script>

<template>
  <div
    ref="container"
    role="region"
    tabindex="0"
    :aria-label="ariaLabel"
    class="overflow-x-auto overflow-y-hidden rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
    data-test="column-scroll"
  >
    <svg
      role="img"
      :aria-label="ariaLabel"
      :width="width"
      :height="HEIGHT"
      :viewBox="`0 0 ${width} ${HEIGHT}`"
      class="block"
      data-test="column-bars"
      @pointerleave="hovered = null"
    >
      <line
        :x1="MARGIN.left"
        :x2="width - MARGIN.right"
        :y1="baseline"
        :y2="baseline"
        class="stroke-n-slate-5"
        stroke-width="1"
      />
      <g
        v-for="bar in bars"
        :key="bar.index"
        @pointermove="hovered = bar.index"
      >
        <title>{{ bar.title }}</title>
        <rect
          :x="bar.x - 2"
          :y="MARGIN.top"
          :width="barWidth + 4"
          :height="plotHeight"
          fill="transparent"
        />
        <rect
          v-if="bar.value > 0"
          :x="bar.x"
          :y="bar.y"
          :width="barWidth"
          :height="Math.max(2, bar.height)"
          rx="2"
          :fill="color"
          :fill-opacity="bar.isPeak || bar.index === hovered ? 1 : 0.55"
          data-test="column"
          :data-peak="bar.isPeak"
        />
        <line
          v-else
          :x1="bar.x"
          :x2="bar.x + barWidth"
          :y1="baseline - 1"
          :y2="baseline - 1"
          class="stroke-n-slate-8"
          stroke-width="2"
          stroke-dasharray="2 2"
          data-test="empty-tick"
        />
      </g>
      <g aria-hidden="true">
        <text
          v-for="bar in marked"
          :key="`value-${bar.index}`"
          :x="bar.x + barWidth / 2"
          :y="bar.y - 6"
          text-anchor="middle"
          class="fill-n-slate-12 text-xs font-semibold tabular-nums"
          data-test="column-value"
        >
          {{ formatCompact(bar.value, locale) }}
        </text>
        <text
          v-for="label in xLabels"
          :key="`x-${label.index}`"
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
