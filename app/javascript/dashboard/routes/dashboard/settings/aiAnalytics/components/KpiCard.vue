<script setup>
import InfoTip from './InfoTip.vue';
import SparkLine from './SparkLine.vue';

// One of the four numbers at the top: a colored dot, the name, the number, how it moved (a sparkline, or a thin bar for
// a share) and one line of context.
defineProps({
  label: { type: String, required: true },
  info: { type: String, default: '' },
  color: { type: String, required: true },
  value: { type: String, required: true },
  context: { type: String, default: '' },
  // [numbers per day]; leave out for a card without a sparkline
  spark: { type: Array, default: null },
  sparkLabel: { type: String, default: '' },
  // { share: number | null (percent), label: string } for a card that shows a share as a thin bar
  bar: { type: Object, default: null },
  loading: { type: Boolean, default: false },
});
</script>

<template>
  <article
    class="flex min-w-0 flex-col gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-4 sm:p-5"
    :aria-busy="loading"
    data-test="kpi-card"
  >
    <div class="flex items-center gap-2">
      <span
        class="size-2.5 shrink-0 rounded-full"
        :style="{ background: color }"
        aria-hidden="true"
      />
      <h2
        class="m-0 flex min-w-0 items-center gap-1 text-sm font-medium text-n-slate-11"
      >
        <span class="min-w-0">{{ label }}</span>
        <InfoTip v-if="info" :text="info" />
      </h2>
    </div>

    <div
      v-if="loading"
      role="status"
      class="flex animate-pulse flex-col gap-3"
      data-test="kpi-loading"
    >
      <div class="h-9 w-24 rounded bg-n-alpha-2" />
      <div class="h-11 w-40 max-w-full rounded bg-n-alpha-2" />
      <div class="h-4 w-32 rounded bg-n-alpha-2" />
    </div>

    <template v-else>
      <p
        class="m-0 text-4xl font-bold leading-none tabular-nums text-n-slate-12"
        data-test="kpi-value"
      >
        {{ value }}
      </p>
      <SparkLine
        v-if="spark"
        :values="spark"
        :color="color"
        :label="sparkLabel || label"
      />
      <div v-else-if="bar" class="flex h-11 items-center" data-test="kpi-bar">
        <div
          role="img"
          :aria-label="bar.label"
          class="h-1.5 w-full max-w-40 overflow-hidden rounded-full bg-n-alpha-3"
        >
          <div
            class="h-full rounded-full"
            :style="{ width: `${bar.share || 0}%`, background: color }"
          />
        </div>
      </div>
      <p
        class="m-0 text-xs tabular-nums text-n-slate-11"
        data-test="kpi-context"
      >
        {{ context }}
      </p>
    </template>
  </article>
</template>
