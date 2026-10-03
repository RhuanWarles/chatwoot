<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { dealsAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import CrmCurrencyInput from './CrmCurrencyInput.vue';
import { brlFormatter } from './currencyHelpers';

const props = defineProps({ dealId: { type: Number, required: true } });
const emit = defineEmits(['changed']);
const { t, locale } = useI18n();
const fields = ref([]);
const draft = ref({});
const editing = ref(false);
const saving = ref(false);
const loading = ref(false);
const error = ref('');
const currencies = ref([]);
const empty = value =>
  value == null || value === '' || (Array.isArray(value) && !value.length);
const display = (field, value) => {
  if (empty(value)) return t('CRM.NOT_SET');
  if (field.field_type === 'boolean')
    return t(value ? 'CRM.CF_YES' : 'CRM.CF_NO');
  if (field.field_type === 'currency') return brlFormatter.format(value);
  if (field.field_type === 'multiselect') return value.join(', ');
  if (field.field_type === 'date')
    return new Intl.DateTimeFormat(locale.value.replace('_', '-')).format(
      new Date(value + 'T12:00:00')
    );
  if (field.field_type === 'datetime')
    return new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(new Date(value));
  return value;
};
const localDatetime = value => {
  if (!value) return '';
  const date = new Date(value);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
};
const inputValue = field => {
  if (field.field_type === 'datetime') return localDatetime(field.value);
  if (field.field_type === 'multiselect') return [...(field.value || [])];
  return field.value ?? '';
};
const load = async () => {
  loading.value = true;
  error.value = '';
  editing.value = false;
  try {
    fields.value = (await dealsAPI.customFields(props.dealId)).data;
  } catch {
    error.value = t('CRM.CF_LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
const edit = () => {
  draft.value = Object.fromEntries(
    fields.value.map(field => [field.key, inputValue(field)])
  );
  error.value = '';
  editing.value = true;
};
const normalized = field => {
  const value = draft.value[field.key];
  if (empty(value)) return null;
  if (['number', 'currency'].includes(field.field_type)) return Number(value);
  if (field.field_type === 'datetime') return new Date(value).toISOString();
  return value;
};
const invalid = computed(() =>
  fields.value.some(field => {
    const value = draft.value[field.key];
    if (field.required && empty(value)) return true;
    return (
      ['number', 'currency'].includes(field.field_type) &&
      !empty(value) &&
      !Number.isFinite(Number(value))
    );
  })
);
const save = async () => {
  if (saving.value) return;
  if (invalid.value || currencies.value.some(input => input.isInvalid)) {
    error.value = t('CRM.CF_INVALID');
    return;
  }
  saving.value = true;
  error.value = '';
  try {
    const values = {};
    fields.value.forEach(field => {
      if (
        JSON.stringify(draft.value[field.key]) ===
        JSON.stringify(inputValue(field))
      )
        return;
      const value = normalized(field);
      if (JSON.stringify(value) !== JSON.stringify(field.value))
        values[field.key] = value;
    });
    if (Object.keys(values).length) {
      fields.value = (
        await dealsAPI.updateCustomFields(props.dealId, values)
      ).data;
      emit('changed');
    }
    editing.value = false;
  } catch (failure) {
    error.value = failure.response?.data?.error || t('CRM.CF_SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
watch(() => props.dealId, load, { immediate: true });
</script>

<template>
  <section class="flex flex-col gap-4 p-4 rounded-lg bg-n-solid-2">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h2 class="m-0 text-base font-medium text-n-slate-12">
        {{ t('CRM.CUSTOM_FIELDS_TITLE') }}
      </h2>
      <Button
        v-if="fields.length && !editing"
        variant="ghost"
        :label="t('CRM.EDIT')"
        @click="edit"
      />
    </div>
    <p v-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <p v-if="loading" class="m-0 text-sm text-n-slate-11">
      {{ t('CRM.CF_LOADING') }}
    </p>
    <Button
      v-if="error && !editing"
      variant="ghost"
      :label="t('CRM.RETRY')"
      @click="load"
    />
    <p
      v-if="!loading && !fields.length && !error"
      class="m-0 text-sm text-n-slate-11"
    >
      {{ t('CRM.NO_CUSTOM_FIELDS') }}
    </p>
    <form
      v-if="fields.length && editing"
      class="flex flex-col gap-4"
      @submit.prevent="save"
    >
      <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div
          v-for="field in fields"
          :key="field.id"
          class="flex flex-col min-w-0 gap-2"
        >
          <label
            :for="'cf-' + field.id"
            class="text-sm font-medium text-n-slate-12"
            >{{ field.name
            }}<span v-if="field.required" aria-hidden="true"> *</span></label
          >
          <CrmCurrencyInput
            v-if="field.field_type === 'currency'"
            ref="currencies"
            v-model="draft[field.key]"
            :label="field.name"
            :disabled="saving"
          />
          <textarea
            v-else-if="field.field_type === 'textarea'"
            :id="'cf-' + field.id"
            v-model="draft[field.key]"
            :required="field.required"
            :disabled="saving"
            rows="3"
            class="w-full p-2 border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
          />
          <input
            v-else-if="field.field_type === 'boolean'"
            :id="'cf-' + field.id"
            v-model="draft[field.key]"
            type="checkbox"
            :disabled="saving"
            class="self-start"
          />
          <select
            v-else-if="['select', 'multiselect'].includes(field.field_type)"
            :id="'cf-' + field.id"
            v-model="draft[field.key]"
            :multiple="field.field_type === 'multiselect'"
            :required="field.required"
            :disabled="saving"
            class="w-full p-2 border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
          >
            <option v-if="field.field_type === 'select'" value="">
              {{ t('CRM.NOT_SET') }}
            </option>
            <option
              v-for="option in field.options"
              :key="option"
              :value="option"
            >
              {{ option }}
            </option>
          </select>
          <Input
            v-else
            :id="'cf-' + field.id"
            v-model="draft[field.key]"
            :type="
              field.field_type === 'datetime'
                ? 'datetime-local'
                : field.field_type
            "
            :step="field.field_type === 'number' ? 'any' : undefined"
            :required="field.required"
            :disabled="saving"
          />
        </div>
      </div>
      <div class="flex justify-end gap-2">
        <Button
          type="button"
          variant="ghost"
          :disabled="saving"
          :label="t('CRM.CF_CANCEL')"
          @click="
            editing = false;
            error = '';
          "
        />
        <Button
          type="submit"
          :is-loading="saving"
          :disabled="saving"
          :label="t('CRM.CF_SAVE')"
        />
      </div>
    </form>
    <dl
      v-else-if="fields.length"
      class="grid grid-cols-1 gap-4 m-0 md:grid-cols-2"
    >
      <div v-for="field in fields" :key="field.id" class="min-w-0">
        <dt class="text-sm text-n-slate-11">{{ field.name }}</dt>
        <dd class="m-0 text-sm whitespace-pre-wrap break-words text-n-slate-12">
          {{ display(field, field.value) }}
        </dd>
      </div>
    </dl>
  </section>
</template>
