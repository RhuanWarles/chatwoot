<script setup>
import { computed, ref, useId } from 'vue';
import { useElementSize } from '@vueuse/core';
import {
  areaPath,
  integerTicks,
  labelIndexes,
  linePath,
  nearestIndex,
  spreadLabels,
} from '../chartGeometry';
import { formatDate, formatDayMonth, formatNumber } from '../analyticsFormat';
import { peakOf } from '../analyticsMetrics';

// Activity over time: one line per series, drawn by hand so the screen does not depend on a chart library.
// It opens with the busiest day selected (so there is always a number on screen) and follows the pointer or the arrow keys.
// `points`: [{ date, tokens, ...one number per series key }]
// `series`: [{ key, label, color, width, area }], the first one is the main line and gets the busiest-day dot.
const props = defineProps({
  points: { type: Array, required: true },
  series: { type: Array, required: true },
  totals: { type: Object, default: () => ({}) },
  tokensLabel: { type: String, default: '' },
  ariaLabel: { type: String, required: true },
  scrollLabel: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
});

const HEIGHT = 280;
const MIN_WIDTH = 560;
const MARGIN = { top: 20, right: 150, bottom: 30, left: 40 };
const chartId = useId();

const container = ref(null);
const { width: measured } = useElementSize(container);
const width = computed(() => Math.max(MIN_WIDTH, measured.value || 720));
const plotWidth = computed(() => width.value - MARGIN.left - MARGIN.right);
const plotHeight = HEIGHT - MARGIN.top - MARGIN.bottom;
const baseline = MARGIN.top + plotHeight;

const mainKey = computed(() => props.series[0]?.key);
const peak = computed(() => peakOf(props.points, mainKey.value));
const scale = computed(() =>
  integerTicks(
    Math.max(
      0,
      ...props.series.flatMap(item =>
        props.points.map(point => Number(point[item.key] || 0))
      )
    )
  )
);

const x = index =>
  props.points.length > 1
    ? MARGIN.left + (index * plotWidth.value) / (props.points.length - 1)
    : MARGIN.left + plotWidth.value / 2;
const y = value =>
  baseline - (Number(value || 0) / scale.value.max) * plotHeight;

const lines = computed(() =>
  props.series.map(item => {
    const coordinates = props.points.map((point, index) => [
      x(index),
      y(point[item.key]),
    ]);
    return {
      ...item,
      coordinates,
      path: linePath(coordinates),
      area: item.area ? areaPath(coordinates, baseline) : '',
    };
  })
);
// Drawn from the last to the first so the main line ends up on top.
const drawOrder = computed(() => [...lines.value].reverse());

const hovered = ref(null);
const active = computed(
  () => hovered.value ?? peak.value?.index ?? props.points.length - 1
);
const activePoint = computed(() => props.points[active.value]);

const lastIndex = computed(() => props.points.length - 1);
const endLabels = computed(() => {
  const last = props.points[lastIndex.value];
  const positions = spreadLabels(
    props.series.map(item => ({ id: item.key, y: y(last?.[item.key]) })),
    16,
    MARGIN.top + 6,
    baseline
  );
  return props.series.map(item => ({
    key: item.key,
    color: item.color,
    y: positions[item.key],
    text: `${item.label} ${formatNumber(last?.[item.key], props.locale)}`,
  }));
});

const xLabels = computed(() =>
  labelIndexes(props.points.length, plotWidth.value).map(index => ({
    index,
    text: formatDayMonth(props.points[index].date, props.locale),
  }))
);
const yLabels = computed(() =>
  scale.value.ticks.map(value => ({
    value,
    y: y(value),
    text: formatNumber(value, props.locale),
  }))
);

const tipOnTheLeft = computed(() => x(active.value) > width.value * 0.55);
const tipStyle = computed(() => ({
  left: `${x(active.value)}px`,
  top: `${MARGIN.top}px`,
  transform: tipOnTheLeft.value
    ? 'translateX(calc(-100% - 14px))'
    : 'translateX(14px)',
}));
const tipRows = computed(() => [
  ...props.series.map(item => ({
    key: item.key,
    label: item.label,
    color: item.color,
    value: formatNumber(activePoint.value?.[item.key], props.locale),
  })),
  ...(props.tokensLabel
    ? [
        {
          key: 'tokens',
          label: props.tokensLabel,
          color: 'var(--an-tokens)',
          value: formatNumber(activePoint.value?.tokens, props.locale),
        },
      ]
    : []),
]);

const summary = computed(() =>
  [
    props.ariaLabel,
    ...props.series.map(
      item =>
        `${item.label}: ${formatNumber(props.totals[item.key], props.locale)}`
    ),
  ].join('. ')
);

const onPointer = event => {
  const box = event.currentTarget.getBoundingClientRect();
  hovered.value = nearestIndex(
    event.clientX - box.left,
    props.points.length,
    MARGIN.left,
    plotWidth.value
  );
};
// A finger lifted from the screen leaves the chart too; the day it chose should stay on screen.
const onLeave = event => {
  if (event.pointerType !== 'touch') hovered.value = null;
};
const onKey = event => {
  const last = props.points.length - 1;
  const moves = {
    ArrowLeft: () => Math.max(0, active.value - 1),
    ArrowRight: () => Math.min(last, active.value + 1),
    Home: () => 0,
    End: () => last,
    Escape: () => null,
  };
  if (!moves[event.key]) return;
  event.preventDefault();
  hovered.value = moves[event.key]();
};
</script>

<template>
  <div class="flex min-w-0 flex-col gap-3">
    <div
      ref="container"
      role="region"
      tabindex="0"
      :aria-label="scrollLabel || ariaLabel"
      class="overflow-x-auto overflow-y-hidden rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      data-test="activity-scroll"
      @keydown="onKey"
      @blur="hovered = null"
    >
      <div
        class="relative"
        :style="{ width: `${width}px`, height: `${HEIGHT}px` }"
      >
        <svg
          role="img"
          :aria-label="summary"
          :width="width"
          :height="HEIGHT"
          :viewBox="`0 0 ${width} ${HEIGHT}`"
          class="block touch-pan-y select-none"
          data-test="activity-chart"
          @pointermove="onPointer"
          @pointerdown="onPointer"
          @pointerleave="onLeave"
        >
          <defs>
            <template v-for="line in lines" :key="`gradient-${line.key}`">
              <linearGradient
                v-if="line.area"
                :id="`${chartId}-${line.key}`"
                x1="0"
                y1="0"
                x2="0"
                y2="1"
              >
                <stop offset="0%" :stop-color="line.color" stop-opacity="0.3" />
                <stop offset="100%" :stop-color="line.color" stop-opacity="0" />
              </linearGradient>
            </template>
          </defs>

          <g aria-hidden="true">
            <g v-for="tick in yLabels" :key="tick.value">
              <line
                :x1="MARGIN.left"
                :x2="MARGIN.left + plotWidth"
                :y1="tick.y"
                :y2="tick.y"
                class="stroke-n-slate-5"
                stroke-width="1"
                data-test="gridline"
              />
              <text
                :x="MARGIN.left - 8"
                :y="tick.y + 4"
                text-anchor="end"
                class="fill-n-slate-11 text-xs tabular-nums"
                data-test="y-label"
              >
                {{ tick.text }}
              </text>
            </g>
            <text
              v-for="label in xLabels"
              :key="label.index"
              :x="x(label.index)"
              :y="HEIGHT - 8"
              text-anchor="middle"
              class="fill-n-slate-11 text-xs tabular-nums"
              data-test="x-label"
            >
              {{ label.text }}
            </text>

            <template v-for="line in drawOrder" :key="line.key">
              <path
                v-if="line.area"
                :d="line.area"
                :fill="`url(#${chartId}-${line.key})`"
              />
              <path
                :d="line.path"
                fill="none"
                :stroke="line.color"
                :stroke-width="line.width"
                stroke-linecap="round"
                stroke-linejoin="round"
                data-test="series-line"
              />
            </template>

            <line
              :x1="x(active)"
              :x2="x(active)"
              :y1="MARGIN.top"
              :y2="baseline"
              class="stroke-n-slate-8"
              stroke-width="1"
              stroke-dasharray="3 3"
              data-test="crosshair"
            />

            <template v-for="line in lines" :key="`dots-${line.key}`">
              <circle
                v-if="line.key === mainKey && peak"
                :cx="x(peak.index)"
                :cy="y(points[peak.index][line.key])"
                r="4"
                :fill="line.color"
                class="stroke-n-solid-1"
                stroke-width="2"
                data-test="peak-dot"
              />
              <circle
                :cx="x(lastIndex)"
                :cy="y(points[lastIndex][line.key])"
                r="3.5"
                :fill="line.color"
                class="stroke-n-solid-1"
                stroke-width="2"
                data-test="last-dot"
              />
              <circle
                v-if="hovered !== null || (peak && active !== peak.index)"
                :cx="x(active)"
                :cy="y(activePoint?.[line.key])"
                r="4.5"
                :fill="line.color"
                class="stroke-n-solid-1"
                stroke-width="2"
              />
            </template>

            <g v-for="label in endLabels" :key="label.key">
              <circle
                :cx="x(lastIndex) + 14"
                :cy="label.y"
                r="4"
                :fill="label.color"
              />
              <text
                :x="x(lastIndex) + 24"
                :y="label.y + 4"
                class="fill-n-slate-12 text-xs font-medium tabular-nums"
                data-test="end-label"
              >
                {{ label.text }}
              </text>
            </g>
          </g>
        </svg>

        <div
          v-if="activePoint"
          class="pointer-events-none absolute z-10 w-44 rounded-lg border border-n-weak bg-n-solid-3 p-2.5 text-xs shadow-lg"
          :style="tipStyle"
          aria-hidden="true"
          data-test="activity-tooltip"
        >
          <p class="m-0 font-semibold text-n-slate-12">
            {{ formatDate(activePoint.date, locale) }}
          </p>
          <dl class="m-0 mt-1.5 flex flex-col gap-1">
            <div
              v-for="row in tipRows"
              :key="row.key"
              class="flex items-center justify-between gap-2"
            >
              <dt class="flex min-w-0 items-center gap-1.5 text-n-slate-11">
                <span
                  class="size-2 shrink-0 rounded-full"
                  :style="{ background: row.color }"
                />
                <span class="truncate">{{ row.label }}</span>
              </dt>
              <dd class="m-0 font-semibold tabular-nums text-n-slate-12">
                {{ row.value }}
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </div>

    <ul
      class="m-0 flex list-none flex-wrap gap-x-5 gap-y-1.5 p-0 text-xs text-n-slate-11"
      data-test="activity-legend"
    >
      <li
        v-for="item in series"
        :key="item.key"
        class="flex items-center gap-1.5"
      >
        <span
          class="size-2.5 rounded-full"
          :style="{ background: item.color }"
          aria-hidden="true"
        />
        {{ item.label }}
        <strong class="font-semibold tabular-nums text-n-slate-12">{{
          formatNumber(totals[item.key], locale)
        }}</strong>
      </li>
    </ul>
  </div>
</template>
