<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <div
    role="status"
    :aria-label="t('AI_HUB.LOADING')"
    class="flex flex-col gap-6 p-6 animate-pulse"
  >
    <div class="flex items-center gap-3">
      <div class="h-7 rounded-lg w-52 bg-n-alpha-2" />
      <div class="w-20 h-5 rounded-full bg-n-alpha-2" />
    </div>
    <div class="h-10 rounded-xl bg-n-alpha-1" />
    <div class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2">
      <div class="w-40 h-5 rounded-md bg-n-alpha-2" />
      <div class="h-10 rounded-lg bg-n-alpha-2" />
      <div class="h-10 rounded-lg bg-n-alpha-2" />
      <div class="h-24 rounded-lg bg-n-alpha-2" />
    </div>
  </div>
</template>
