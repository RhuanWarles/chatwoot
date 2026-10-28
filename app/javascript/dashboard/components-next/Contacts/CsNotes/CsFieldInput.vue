<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  field: { type: Object, required: true },
  modelValue: { type: [String, Number, Boolean], default: '' },
});

// Sent when the person leaves the field, not on every key they press.
const emit = defineEmits(['commit']);

const { t } = useI18n();
const local = ref(props.modelValue);

watch(
  () => props.modelValue,
  value => {
    local.value = value;
  }
);

const type = computed(() => props.field.attribute_display_type);
const inputType = computed(
  () =>
    ({
      number: 'number',
      currency: 'number',
      percent: 'number',
      link: 'url',
      date: 'date',
    })[type.value] ?? 'text'
);

const listOptions = computed(() => [
  { value: '', label: t('CS_NOTES.NO_VALUE') },
  ...(props.field.attribute_values ?? []).map(value => ({
    value,
    label: value,
  })),
]);

const commit = value => {
  if (value === props.modelValue || (value === '' && !props.modelValue)) return;
  emit('commit', value);
};
</script>

<template>
  <label
    v-if="type === 'checkbox'"
    class="flex items-center gap-2 text-sm text-n-slate-12"
  >
    <input
      type="checkbox"
      class="m-0"
      :checked="local === true"
      :data-test="`cs-field-${field.attribute_key}`"
      @change="commit($event.target.checked)"
    />
    <span>{{ t('CS_NOTES.YES') }}</span>
  </label>
  <Select
    v-else-if="type === 'list'"
    v-model="local"
    class="!w-full"
    :options="listOptions"
    :aria-label="field.attribute_display_name"
    :data-test="`cs-field-${field.attribute_key}`"
    @update:model-value="commit"
  />
  <TextArea
    v-else-if="type === 'text'"
    v-model="local"
    :max-length="5000"
    auto-height
    min-height="2.5rem"
    :data-test="`cs-field-${field.attribute_key}`"
    @blur="commit(local)"
  />
  <Input
    v-else
    v-model="local"
    :type="inputType"
    :data-test="`cs-field-${field.attribute_key}`"
    @blur="commit(local)"
  />
</template>
