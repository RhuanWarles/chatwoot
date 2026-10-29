<script setup>
defineProps({
  label: { type: String, default: '' },
  hint: { type: String, default: '' },
  error: { type: String, default: '' },
});
</script>

<template>
  <div class="flex flex-col gap-1.5 min-w-0">
    <span v-if="label" class="text-label-small text-n-slate-11">
      {{ label }}
    </span>
    <slot />
    <span v-if="hint && !error" class="text-xs text-n-slate-10">{{
      hint
    }}</span>
    <span v-if="error" class="text-xs text-n-ruby-11">{{ error }}</span>
  </div>
</template>
