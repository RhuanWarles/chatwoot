<script setup>
import { computed } from 'vue';
import InfoTip from './InfoTip.vue';

// A number with its name. `tone` colors the value only when it means something: a zero or a missing value is grey, never
// green or red.
const props = defineProps({
  label: { type: String, required: true },
  value: { type: String, required: true },
  sub: { type: String, default: '' },
  info: { type: String, default: '' },
  tone: {
    type: String,
    default: 'neutral',
    validator: value => ['neutral', 'good', 'bad', 'muted'].includes(value),
  },
});

const valueClass = computed(
  () =>
    ({
      neutral: 'text-n-slate-12',
      good: 'text-n-teal-11',
      bad: 'text-n-ruby-11',
      muted: 'text-n-slate-11',
    })[props.tone]
);
</script>

<template>
  <div class="min-w-0 rounded-lg bg-n-alpha-2 p-3">
    <dt class="flex items-center gap-1 text-xs text-n-slate-11">
      <span class="min-w-0">{{ label }}</span>
      <InfoTip v-if="info" :text="info" />
    </dt>
    <dd
      class="m-0 mt-1 text-xl font-semibold tabular-nums"
      :class="valueClass"
      data-test="tile-value"
    >
      {{ value }}
    </dd>
    <p v-if="sub" class="m-0 mt-0.5 text-xs tabular-nums text-n-slate-11">
      {{ sub }}
    </p>
  </div>
</template>
