<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { LineChart } from '@chatwoot/viz';
import { nearestDataIndex, tooltipRowsForIndex } from './activityChart';

const props = defineProps({
  ariaLabel: {
    type: String,
    default: 'Line chart',
  },
  data: {
    type: Object,
    required: true,
  },
  formatValue: {
    type: Function,
    required: true,
  },
  height: {
    type: Number,
    required: true,
  },
  pointRadius: {
    type: Number,
    default: 3,
  },
  width: {
    type: Number,
    required: true,
  },
});

const chartRoot = ref(null);
const activeIndex = ref(null);
const pointerX = ref(null);
const categoryPositions = ref([]);
let resizeObserver;

const activeCategory = computed(() => {
  if (activeIndex.value === null) return null;
  return props.data.categories?.[activeIndex.value] || null;
});

const tooltipRows = computed(() => {
  if (activeIndex.value === null) return [];
  return tooltipRowsForIndex(props.data, activeIndex.value, props.formatValue);
});

const tooltipAlignment = computed(() => {
  const x = pointerX.value || 0;
  const chartWidth =
    chartRoot.value?.getBoundingClientRect().width || props.width;

  if (x < chartWidth * 0.25) return 'start';
  if (x > chartWidth * 0.75) return 'end';
  return 'center';
});

const tooltipClasses = computed(() => ({
  'translate-x-0': tooltipAlignment.value === 'start',
  '-translate-x-1/2': tooltipAlignment.value === 'center',
  '-translate-x-full': tooltipAlignment.value === 'end',
}));

const positionForTick = tick => {
  const rootRect = chartRoot.value?.getBoundingClientRect();
  if (!rootRect) return null;

  const tickMark = tick.querySelector('.cw-viz-line__tick-mark');
  const matrix = tickMark?.getScreenCTM?.();
  if (matrix) return matrix.e - rootRect.left;

  const transform = tick.getAttribute('transform') || '';
  const transformMatch = transform.match(/translate\(\s*([\d.-]+)/);
  const svg = tick.ownerSVGElement;
  const svgRect = svg?.getBoundingClientRect();
  const viewBoxWidth = svg?.viewBox?.baseVal?.width;
  if (transformMatch && svgRect && viewBoxWidth) {
    return (
      svgRect.left -
      rootRect.left +
      (Number(transformMatch[1]) / viewBoxWidth) * svgRect.width
    );
  }

  const tickRect = tick.getBoundingClientRect();
  return tickRect.left + tickRect.width / 2 - rootRect.left;
};

const syncCategoryPositions = () => {
  const ticks = chartRoot.value?.querySelectorAll('.cw-viz-line__x-tick');
  categoryPositions.value = ticks
    ? Array.from(ticks).map(positionForTick).filter(Number.isFinite)
    : [];
};

const selectCategory = index => {
  if (index === null || index === undefined) return;

  activeIndex.value = index;
  pointerX.value = categoryPositions.value[index] ?? null;
};

const selectFromPointer = event => {
  const rootRect = chartRoot.value?.getBoundingClientRect();
  if (!rootRect) return;

  if (!categoryPositions.value.length) syncCategoryPositions();

  const nextIndex = nearestDataIndex(
    categoryPositions.value,
    event.clientX - rootRect.left
  );
  selectCategory(nextIndex);
};

const onChartItemClick = point => {
  selectCategory(point?.pointIndex);
};

const clearSelection = () => {
  activeIndex.value = null;
  pointerX.value = null;
};

const refreshPositions = () => nextTick(syncCategoryPositions);

watch(() => props.data, refreshPositions, { deep: true });

onMounted(() => {
  refreshPositions();
  resizeObserver = new ResizeObserver(refreshPositions);
  if (chartRoot.value) resizeObserver.observe(chartRoot.value);
});

onBeforeUnmount(() => resizeObserver?.disconnect());
</script>

<template>
  <div
    ref="chartRoot"
    class="relative w-full min-w-0"
    @pointermove="selectFromPointer"
    @pointerleave="clearSelection"
    @click="selectFromPointer"
    @keydown.esc="clearSelection"
  >
    <LineChart
      :data="data"
      :height="height"
      :width="width"
      :point-radius="pointRadius"
      :show-tooltip="false"
      :show-values="false"
      :format-value="formatValue"
      :aria-label="ariaLabel"
      :on-item-click="onChartItemClick"
      class="w-full min-w-0 [&_.cw-viz-line__x-tick]:hidden [&_.cw-viz-line__x-tick:nth-child(4n+1)]:block [&_.cw-viz-line__x-tick:last-child]:block [--cw-viz-line-label-color:rgb(var(--slate-11))] [--cw-viz-line-axis-color:rgb(var(--slate-4))] [--cw-viz-line-tooltip-background:rgb(var(--solid-2))] [--cw-viz-line-tooltip-color:rgb(var(--slate-12))]"
    />

    <div
      v-if="pointerX !== null"
      class="pointer-events-none absolute inset-y-0 z-10 w-px bg-n-slate-7/40"
      :style="{ left: `${pointerX}px` }"
      aria-hidden="true"
    />

    <div
      v-if="activeCategory && pointerX !== null"
      class="pointer-events-none absolute top-2 z-20 min-w-52 rounded-lg border border-n-weak bg-n-solid-2 p-3 text-xs text-n-slate-12 shadow-lg"
      :class="tooltipClasses"
      :style="{ left: `${pointerX}px` }"
      role="tooltip"
    >
      <p class="mb-2 font-medium text-n-slate-11">{{ activeCategory }}</p>
      <div class="flex flex-col gap-1.5">
        <div
          v-for="row in tooltipRows"
          :key="row.label"
          class="flex items-center gap-2"
        >
          <span
            class="size-2 shrink-0 rounded-full"
            :style="{ backgroundColor: row.color }"
            aria-hidden="true"
          />
          <span class="min-w-0 flex-1 truncate">{{ row.label }}</span>
          <strong class="tabular-nums">{{ row.value }}</strong>
        </div>
      </div>
    </div>
  </div>
</template>
