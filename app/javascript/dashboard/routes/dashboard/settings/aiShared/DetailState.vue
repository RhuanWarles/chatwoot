<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

// Empty and error states of the detail panel.
defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  actionLabel: {
    type: String,
    default: '',
  },
  actionIcon: {
    type: String,
    default: '',
  },
  isError: {
    type: Boolean,
    default: false,
  },
});

defineEmits(['action']);
</script>

<template>
  <div class="flex flex-col items-start gap-4 p-6">
    <div
      class="flex flex-col items-start gap-4 w-full max-w-xl p-6 border border-dashed rounded-xl border-n-weak"
      :role="isError ? 'alert' : undefined"
    >
      <div>
        <p
          class="font-medium"
          :class="isError ? 'text-n-ruby-9' : 'text-n-slate-12'"
        >
          {{ title }}
        </p>
        <p v-if="description" class="mt-1 text-sm text-n-slate-11">
          {{ description }}
        </p>
      </div>
      <Button
        v-if="actionLabel"
        :label="actionLabel"
        :icon="actionIcon"
        @click="$emit('action')"
      />
    </div>
  </div>
</template>
