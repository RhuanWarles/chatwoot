<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TemplateTextField from './TemplateTextField.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  // null: the key is typed freely (HTTP headers). Otherwise a list of { value, label }.
  keyOptions: { type: Array, default: null },
  keyPlaceholder: { type: String, default: '' },
  valuePlaceholder: { type: String, default: '' },
  addLabel: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const setRow = (index, patch) =>
  emit(
    'update:modelValue',
    props.modelValue.map((row, position) =>
      position === index ? { ...row, ...patch } : row
    )
  );

const removeRow = index =>
  emit(
    'update:modelValue',
    props.modelValue.filter((row, position) => position !== index)
  );

const addRow = () =>
  emit('update:modelValue', [...props.modelValue, { key: '', value: '' }]);
</script>

<template>
  <div class="flex flex-col gap-3">
    <div
      v-for="(row, index) in modelValue"
      :key="index"
      class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-1"
    >
      <div class="flex items-start gap-2">
        <div class="flex-1 min-w-0">
          <ComboBox
            v-if="keyOptions"
            :model-value="row.key"
            :options="keyOptions"
            :display-label="row.key"
            :placeholder="keyPlaceholder"
            :search-placeholder="t('AUTOMATION.WORKFLOWS.INSPECTOR.SEARCH')"
            @update:model-value="setRow(index, { key: $event })"
          />
          <Input
            v-else
            :model-value="row.key"
            size="sm"
            :placeholder="keyPlaceholder"
            @update:model-value="setRow(index, { key: $event })"
          />
        </div>
        <Button
          ghost
          slate
          sm
          icon="i-lucide-trash-2"
          :aria-label="t('AUTOMATION.WORKFLOWS.INSPECTOR.REMOVE')"
          @click="removeRow(index)"
        />
      </div>
      <TemplateTextField
        :model-value="row.value"
        :placeholder="valuePlaceholder"
        @update:model-value="setRow(index, { value: $event })"
      />
    </div>
    <Button
      faded
      slate
      sm
      icon="i-lucide-plus"
      :label="addLabel"
      @click="addRow"
    />
  </div>
</template>
