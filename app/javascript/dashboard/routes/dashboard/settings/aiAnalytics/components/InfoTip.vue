<script setup>
// The small "i" next to a metric: says in plain words what the number counts. A real button, so it can be reached with
// the keyboard and tapped on a phone, with a hit area of 44px around the 16px icon.
defineProps({
  text: { type: String, required: true },
});
</script>

<template>
  <button
    v-tooltip.top="text"
    type="button"
    :aria-label="text"
    class="relative inline-flex size-5 shrink-0 items-center justify-center rounded-full text-n-slate-11 outline-none before:absolute before:-inset-3 before:content-[''] hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
    data-test="info-tip"
  >
    <span class="i-lucide-info size-4" aria-hidden="true" />
  </button>
</template>
