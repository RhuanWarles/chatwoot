<script setup>
import Select from 'dashboard/components-next/select/Select.vue';

defineProps({
  options: { type: Array, default: () => [] },
  groups: { type: Array, default: () => [] },
  placeholder: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
  error: { type: String, default: '' },
});

const modelValue = defineModel({
  type: [String, Number, Boolean],
  default: '',
});
</script>

<template>
  <div class="w-full [&>div]:w-full [&_select]:w-full">
    <Select
      v-model="modelValue"
      :options="options"
      :groups="groups"
      :placeholder="placeholder"
      :disabled="disabled"
      :error="error"
    />
  </div>
</template>
