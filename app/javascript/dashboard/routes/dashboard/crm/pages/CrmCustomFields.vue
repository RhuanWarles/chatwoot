<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { customFieldsAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const { t } = useI18n();
const fields = ref([]);
const editor = ref(null);
const saving = ref(false);
const draft = ref({
  name: '',
  field_type: 'text',
  required: false,
  options: [],
});
const types = [
  'text',
  'textarea',
  'number',
  'currency',
  'date',
  'datetime',
  'boolean',
  'select',
  'multiselect',
];
const load = async () => {
  fields.value = (await customFieldsAPI.get()).data;
};
const openNew = () => {
  draft.value = { name: '', field_type: 'text', required: false, options: [] };
  editor.value.open();
};
const addOption = () => {
  draft.value.options.push('');
};
const save = async () => {
  if (!draft.value.name.trim() || saving.value) return;
  saving.value = true;
  try {
    const payload = {
      custom_field: {
        ...draft.value,
        options: draft.value.options.filter(Boolean),
      },
    };
    if (draft.value.id) await customFieldsAPI.update(draft.value.id, payload);
    else await customFieldsAPI.create(payload);
    editor.value.close();
    await load();
  } finally {
    saving.value = false;
  }
};
const edit = field => {
  draft.value = { ...field, options: [...(field.options || [])] };
  editor.value.open();
};
const toggle = async field => {
  await customFieldsAPI.update(field.id, {
    custom_field: { active: !field.active },
  });
  await load();
};
onMounted(load);
</script>

<template>
  <main
    class="flex flex-1 flex-col w-full h-full min-w-0 min-h-0 p-6 overflow-auto bg-n-background"
  >
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('CRM.CUSTOM_FIELDS_TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('CRM.CUSTOM_FIELDS_SUBTITLE') }}
        </p>
      </div>
      <Button
        :label="t('CRM.NEW_CUSTOM_FIELD')"
        icon="i-lucide-plus"
        @click="openNew"
      />
    </div>
    <div class="flex flex-col gap-2">
      <div
        v-for="field in fields"
        :key="field.id"
        class="flex items-center justify-between p-4 rounded-lg bg-n-solid-2"
      >
        <div>
          <p class="mb-1 font-medium text-n-slate-12">{{ field.name }}</p>
          <p class="text-xs text-n-slate-11">
            {{ field.field_type }} -
            {{ field.active ? t('CRM.ACTIVE') : t('CRM.INACTIVE') }}
          </p>
        </div>
        <div class="flex gap-2">
          <Button
            variant="ghost"
            :label="t('CRM.EDIT')"
            @click="edit(field)"
          /><Button
            variant="ghost"
            :label="field.active ? t('CRM.DEACTIVATE') : t('CRM.ACTIVATE')"
            @click="toggle(field)"
          />
        </div>
      </div>
      <p v-if="!fields.length" class="text-sm text-n-slate-11">
        {{ t('CRM.NO_CUSTOM_FIELDS') }}
      </p>
    </div>
    <Dialog
      ref="editor"
      :title="draft.id ? t('CRM.EDIT_CUSTOM_FIELD') : t('CRM.NEW_CUSTOM_FIELD')"
      :is-loading="saving"
      @confirm="save"
    >
      <div class="flex flex-col gap-4">
        <Input v-model="draft.name" :label="t('CRM.CUSTOM_FIELD_NAME')" />
        <ComboBox
          v-model="draft.field_type"
          :label="t('CRM.CUSTOM_FIELD_TYPE')"
          :options="types.map(value => ({ value, label: value }))"
        />
        <label class="flex items-center gap-2 text-sm text-n-slate-12"
          ><input v-model="draft.required" type="checkbox" />{{
            t('CRM.CUSTOM_FIELD_REQUIRED')
          }}</label
        >
        <div
          v-if="['select', 'multiselect'].includes(draft.field_type)"
          class="flex flex-col gap-2"
        >
          <p class="text-sm font-medium text-n-slate-12">
            {{ t('CRM.CUSTOM_FIELD_OPTIONS') }}
          </p>
          <Input
            v-for="(_, index) in draft.options"
            :key="index"
            v-model="draft.options[index]"
            :label="t('CRM.CUSTOM_FIELD_OPTION') + ' ' + (index + 1)"
          />
          <Button
            variant="ghost"
            :label="t('CRM.ADD_OPTION')"
            @click="addOption"
          />
        </div>
      </div>
    </Dialog>
  </main>
</template>
