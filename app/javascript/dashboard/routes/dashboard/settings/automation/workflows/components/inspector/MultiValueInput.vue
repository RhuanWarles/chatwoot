<script setup>
import { computed, ref } from 'vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  // null: free text values (type and press Enter). Otherwise a closed list of { value, label }.
  options: { type: Array, default: null },
  placeholder: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const draft = ref('');

const labelOf = value =>
  props.options?.find(option => String(option.value) === String(value))
    ?.label ?? value;

const remaining = computed(() =>
  (props.options || []).filter(
    option => !props.modelValue.map(String).includes(String(option.value))
  )
);

const add = value => {
  const text = String(value ?? '').trim();
  if (!text || props.modelValue.map(String).includes(text)) return;
  emit('update:modelValue', [...props.modelValue, text]);
  draft.value = '';
};

const remove = value =>
  emit(
    'update:modelValue',
    props.modelValue.filter(item => String(item) !== String(value))
  );
</script>

<template>
  <div class="flex flex-col gap-2">
    <div v-if="modelValue.length" class="flex flex-wrap gap-1.5">
      <span
        v-for="value in modelValue"
        :key="value"
        class="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-md bg-n-alpha-2 text-n-slate-12"
      >
        {{ labelOf(value) }}
        <button type="button" class="text-n-slate-11" @click="remove(value)">
          <Icon icon="i-lucide-x" class="size-3" />
        </button>
      </span>
    </div>
    <ComboBox
      v-if="options"
      model-value=""
      :options="remaining"
      :placeholder="placeholder"
      @update:model-value="add"
    />
    <Input
      v-else
      v-model="draft"
      size="sm"
      :placeholder="placeholder"
      @enter="add(draft)"
      @blur="add(draft)"
    />
  </div>
</template>
