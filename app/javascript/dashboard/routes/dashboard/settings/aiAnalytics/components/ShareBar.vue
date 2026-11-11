<script setup>
import { computed } from 'vue';
import { formatNumber, formatPercent } from '../analyticsFormat';
import { percentOf } from '../analyticsMetrics';

// A bar split into parts that add up to 100%, with the count and the share of each part below it.
// `segments`: [{ key, label, value, color }], `color` is any CSS color.
const props = defineProps({
  segments: { type: Array, required: true },
  locale: { type: String, default: 'pt-BR' },
  ariaLabel: { type: String, required: true },
});

const total = computed(() =>
  props.segments.reduce((sum, item) => sum + Number(item.value || 0), 0)
);
const parts = computed(() =>
  props.segments.map(item => ({
    ...item,
    share: percentOf(item.value, total.value),
    count: formatNumber(item.value, props.locale),
  }))
);
const summary = computed(() =>
  [
    props.ariaLabel,
    ...parts.value.map(
      item =>
        `${item.label}: ${item.count} (${formatPercent(item.share, props.locale)})`
    ),
  ].join('. ')
);
</script>

<template>
  <div>
    <div
      role="img"
      :aria-label="summary"
      class="flex h-3 w-full overflow-hidden rounded-full bg-n-alpha-3"
    >
      <div
        v-for="item in parts"
        v-show="item.share"
        :key="item.key"
        class="h-full first:rounded-s-full last:rounded-e-full"
        :style="{ width: `${item.share || 0}%`, background: item.color }"
        data-test="share-segment"
      />
    </div>
    <ul class="m-0 mt-3 flex list-none flex-col gap-1.5 p-0 text-sm">
      <li
        v-for="item in parts"
        :key="item.key"
        class="flex items-center justify-between gap-3"
        data-test="share-item"
      >
        <span class="flex min-w-0 items-center gap-2 text-n-slate-11">
          <span
            class="size-2.5 shrink-0 rounded-sm"
            :style="{ background: item.color }"
            aria-hidden="true"
          />
          <span class="min-w-0">{{ item.label }}</span>
        </span>
        <span class="shrink-0 tabular-nums text-n-slate-12">
          <strong class="font-semibold">{{ item.count }}</strong>
          <span class="ms-1.5 text-n-slate-11">{{
            formatPercent(item.share, locale)
          }}</span>
        </span>
      </li>
    </ul>
  </div>
</template>
