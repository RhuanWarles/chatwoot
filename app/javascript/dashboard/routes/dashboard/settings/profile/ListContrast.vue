<script setup>
import Switch from 'dashboard/components-next/switch/Switch.vue';

defineProps({
  value: {
    type: Boolean,
    default: false,
  },
  label: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['change']);
</script>

<template>
  <div class="flex items-start justify-between w-full gap-2">
    <div>
      <label class="text-sm font-medium leading-6 text-n-gray-12">
        {{ label }}
      </label>
      <p class="text-n-gray-11">
        {{ description }}
      </p>
    </div>
    <Switch
      :model-value="value"
      class="mt-1"
      @update:model-value="emit('change', $event)"
    />
  </div>
</template>
