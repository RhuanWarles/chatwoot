<script setup>
import { computed, useId } from 'vue';
import { areaPath, linePath } from '../chartGeometry';

// The trend of a number over the period, 160x44: a line over a soft gradient. It carries no scale on purpose, the exact
// values are in the big chart and in the table.
const props = defineProps({
  values: { type: Array, required: true },
  color: { type: String, required: true },
  label: { type: String, required: true },
  width: { type: Number, default: 160 },
  height: { type: Number, default: 44 },
});

const gradientId = useId();
const PAD = 3;

const points = computed(() => {
  const values = props.values.map(value => Number(value || 0));
  const max = Math.max(...values, 0);
  const step = values.length > 1 ? props.width / (values.length - 1) : 0;
  const usable = props.height - PAD * 2;
  return values.map((value, index) => [
    values.length > 1 ? index * step : props.width / 2,
    max ? PAD + usable - (value / max) * usable : props.height - PAD,
  ]);
});
const line = computed(() => linePath(points.value));
const area = computed(() => areaPath(points.value, props.height));
const last = computed(() => points.value[points.value.length - 1]);
</script>

<template>
  <svg
    role="img"
    :aria-label="label"
    :viewBox="`0 0 ${width} ${height}`"
    :width="width"
    :height="height"
    class="max-w-full overflow-visible"
    :style="{ color }"
    data-test="sparkline"
  >
    <defs>
      <linearGradient :id="gradientId" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="currentColor" stop-opacity="0.32" />
        <stop offset="100%" stop-color="currentColor" stop-opacity="0" />
      </linearGradient>
    </defs>
    <path v-if="points.length > 1" :d="area" :fill="`url(#${gradientId})`" />
    <path
      v-if="points.length > 1"
      :d="line"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
    <circle v-if="last" :cx="last[0]" :cy="last[1]" r="3" fill="currentColor" />
  </svg>
</template>
