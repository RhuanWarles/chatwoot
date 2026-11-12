<template>
  <div class="flex flex-col gap-2 p-3 animate-pulse" aria-hidden="true">
    <div
      v-for="index in 4"
      :key="index"
      class="flex flex-col gap-2 p-3 rounded-xl bg-n-alpha-1"
    >
      <div class="w-3/4 h-4 rounded-md bg-n-alpha-2" />
      <div class="w-1/2 h-3 rounded-md bg-n-alpha-2" />
    </div>
  </div>
</template>
