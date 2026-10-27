<script setup>
defineProps({
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div
    class="group relative flex w-full flex-col justify-between gap-4 rounded-2xl bg-n-surface-1 p-4 shadow-sm outline outline-1 outline-n-container transition-shadow hover:shadow-md sm:flex-row sm:p-6"
  >
    <slot name="leftSection">
      <div class="flex flex-col min-w-0 items-start gap-3 max-w-[480px] w-full">
        <div
          class="flex items-center justify-between w-full gap-3 sm:justify-normal whitespace-nowrap"
        >
          <h3
            class="justify-between tracking-tight font-medium truncate w-fit sm:justify-normal text-n-slate-12"
          >
            <slot name="title">
              {{ title }}
            </slot>
          </h3>
          <slot name="label" />
        </div>
        <p class="text-base text-n-slate-11 max-w-[25rem] w-full line-clamp-2">
          <slot name="description">
            {{ description }}
          </slot>
        </p>
      </div>
    </slot>

    <!-- right side section -->
    <slot name="rightSection" />

    <!-- actions section -->
    <div
      v-if="$slots.actions"
      class="absolute flex-col items-center hidden gap-1 border-none ltr:-right-3 rtl:-left-3 top-3 group-hover:flex"
    >
      <slot name="actions" />
    </div>
  </div>
</template>
