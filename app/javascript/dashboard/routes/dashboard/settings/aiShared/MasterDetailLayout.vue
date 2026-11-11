<script setup>
// Two independently scrolling panels using the whole content area. Below `md` only one is shown:
// the list, or the detail once an item is open.
defineProps({
  showDetail: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <div class="flex w-full h-full min-h-0 bg-n-surface-1">
    <aside
      class="flex-col w-full min-h-0 border-e md:w-[17.5rem] md:shrink-0 border-n-weak"
      :class="showDetail ? 'hidden md:flex' : 'flex'"
    >
      <slot name="master" />
    </aside>
    <section
      class="flex-col flex-1 min-w-0 min-h-0 overflow-y-auto"
      :class="showDetail ? 'flex' : 'hidden md:flex'"
    >
      <slot />
    </section>
  </div>
</template>
