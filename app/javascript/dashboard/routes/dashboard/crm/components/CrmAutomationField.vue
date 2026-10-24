<script setup>
import { useId } from 'vue';

defineProps({
  label: { type: String, required: true },
  hint: { type: String, default: '' },
  error: { type: String, default: '' },
  group: { type: Boolean, default: false },
});

const id = useId();
const labelId = `${id}-label`;
</script>

<template>
  <div
    class="flex flex-col min-w-0 gap-1.5"
    :role="group ? 'group' : undefined"
    :aria-labelledby="group ? labelId : undefined"
  >
    <span v-if="group" :id="labelId" class="text-heading-3 text-n-slate-12">
      {{ label }}
    </span>
    <label
      v-else
      :id="labelId"
      :for="id"
      class="text-heading-3 text-n-slate-12"
    >
      {{ label }}
    </label>
    <slot :id="id" />
    <p v-if="error" class="m-0 text-label-small text-n-ruby-11">
      {{ error }}
    </p>
    <p v-else-if="hint" class="m-0 text-label-small text-n-slate-11">
      {{ hint }}
    </p>
  </div>
</template>
