<script setup>
import { computed, nextTick, ref, watch } from 'vue';
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
const expanded = ref(true);
const editingId = ref(null);
const editingField = computed(() =>
  fields.value.find(field => field.id === editingId.value)
);
const draft = ref('');
const saving = ref(false);
const loading = ref(false);
const error = ref('');
const currency = ref(null);
const fieldForm = ref(null);
const expandedTexts = ref({});
const PREVIEW_LENGTH = 180;
const empty = value =>
  value == null || value === '' || (Array.isArray(value) && !value.length);
const display = field => {
  const value = field.value;
  if (empty(value)) return t('CRM.NOT_SET');
  if (field.field_type === 'boolean')
    return value ? t('CRM.CF_YES') : t('CRM.CF_NO');
  if (field.field_type === 'currency') return brlFormatter.format(value);
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
const longText = field =>
  field.field_type === 'textarea' &&
  field.value &&
  (field.value.length > PREVIEW_LENGTH || field.value.split('\n').length > 3);
const inputValue = field => {
  if (field.field_type === 'datetime' && field.value) {
    const date = new Date(field.value);
    return new Date(date.getTime() - date.getTimezoneOffset() * 60000)
      .toISOString()
      .slice(0, 16);
  }
  if (field.field_type === 'multiselect') return [...(field.value || [])];
  return field.value ?? '';
};
const cancel = async () => {
  const id = editingId.value;
  editingId.value = null;
  draft.value = '';
  error.value = '';
  await nextTick();
  document.getElementById('cf-read-' + id)?.focus();
};
const load = async () => {
  loading.value = true;
  error.value = '';
  editingId.value = null;
  expandedTexts.value = {};
  fields.value = [];
  try {
    fields.value = (await dealsAPI.customFields(props.dealId)).data;
  } catch {
    error.value = t('CRM.CF_LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
const edit = async field => {
  if (saving.value) return;
  editingId.value = field.id;
  draft.value = inputValue(field);
  error.value = '';
  await nextTick();
  fieldForm.value?.[0]?.querySelector('input, textarea, select')?.focus();
};
const save = async () => {
  if (saving.value || !editingField.value) return;
  const field = editingField.value;
  const value = draft.value;
  const missing = empty(value) || (typeof value === 'string' && !value.trim());
  if (
    (field.required && missing) ||
    (['number', 'currency'].includes(field.field_type) &&
      !missing &&
      !Number.isFinite(Number(value))) ||
    currency.value?.[0]?.isInvalid
  ) {
    error.value = t('CRM.CF_INVALID');
    return;
  }
  saving.value = true;
  error.value = '';
  try {
    if (JSON.stringify(value) !== JSON.stringify(inputValue(field))) {
      let normalized = missing ? null : value;
      if (!missing && ['number', 'currency'].includes(field.field_type))
        normalized = Number(value);
      if (!missing && field.field_type === 'datetime')
        normalized = new Date(value).toISOString();
      if (JSON.stringify(normalized) !== JSON.stringify(field.value)) {
        const result = await dealsAPI.updateCustomFields(props.dealId, {
          [field.key]: normalized,
        });
        fields.value = result.data;
        emit('changed');
      }
    }
    await cancel();
  } catch (failure) {
    error.value = failure.response?.data?.error || t('CRM.CF_SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
watch(() => props.dealId, load, { immediate: true });
</script>

<template>
  <section class="min-w-0 border-t border-n-weak">
    <button
      type="button"
      class="flex items-center gap-2 w-full py-3 text-start text-sm font-semibold text-n-slate-12"
      :aria-expanded="expanded"
      :aria-controls="'deal-details-' + dealId"
      @click="expanded = !expanded"
    >
      <span
        class="size-4 shrink-0"
        :class="expanded ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
        aria-hidden="true"
      />
      {{ t('CRM.SIDEBAR_DETAILS') }}
    </button>
    <div
      v-show="expanded"
      :id="'deal-details-' + dealId"
      class="flex flex-col gap-2 pb-4"
    >
      <p
        v-if="error && !editingField"
        role="alert"
        class="m-0 text-sm text-n-ruby-11"
      >
        {{ error }}
      </p>
      <p v-if="loading" class="m-0 text-sm text-n-slate-11">
        {{ t('CRM.CF_LOADING') }}
      </p>
      <Button
        v-if="error && !editingField"
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
      <div v-for="field in fields" :key="field.id" class="min-w-0">
        <form
          v-if="editingId === field.id"
          ref="fieldForm"
          class="flex flex-col gap-2 p-2 rounded-lg border border-n-brand"
          @submit.prevent="save"
          @keydown.esc.stop.prevent="!saving && cancel()"
        >
          <label
            v-if="
              field.field_type !== 'currency' && field.field_type !== 'boolean'
            "
            :for="'cf-' + field.id"
            class="text-xs text-n-slate-11"
          >
            <span>{{ field.name }}</span>
            <span v-if="field.required" aria-hidden="true"> *</span>
          </label>
          <CrmCurrencyInput
            v-if="field.field_type === 'currency'"
            ref="currency"
            v-model="draft"
            :label="field.name"
            :disabled="saving"
          />
          <textarea
            v-else-if="field.field_type === 'textarea'"
            :id="'cf-' + field.id"
            v-model="draft"
            :required="field.required"
            :disabled="saving"
            rows="4"
            class="w-full p-2 border rounded-lg border-n-weak bg-n-solid-1 text-sm text-n-slate-12"
          />
          <fieldset
            v-else-if="field.field_type === 'boolean'"
            :disabled="saving"
            class="flex flex-wrap gap-4 m-0 p-0 border-0"
          >
            <legend class="mb-2 text-xs text-n-slate-11">
              {{ field.name }}
            </legend>
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input
                v-model="draft"
                type="radio"
                :name="'cf-' + field.id"
                :value="true"
                :required="field.required"
              />
              {{ t('CRM.CF_YES') }}
            </label>
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input
                v-model="draft"
                type="radio"
                :name="'cf-' + field.id"
                :value="false"
                :required="field.required"
              />
              {{ t('CRM.CF_NO') }}
            </label>
          </fieldset>
          <select
            v-else-if="['select', 'multiselect'].includes(field.field_type)"
            :id="'cf-' + field.id"
            v-model="draft"
            :multiple="field.field_type === 'multiselect'"
            :required="field.required"
            :disabled="saving"
            class="w-full p-2 border rounded-lg border-n-weak bg-n-solid-1 text-sm text-n-slate-12"
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
            v-model="draft"
            :type="
              field.field_type === 'datetime'
                ? 'datetime-local'
                : field.field_type
            "
            :step="field.field_type === 'number' ? 'any' : undefined"
            :required="field.required"
            :disabled="saving"
          />
          <p v-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
            {{ error }}
          </p>
          <div class="flex flex-wrap justify-end gap-2">
            <Button
              type="button"
              size="sm"
              variant="ghost"
              :disabled="saving"
              :label="t('CRM.CF_CANCEL')"
              @click="cancel"
            />
            <Button
              type="submit"
              size="sm"
              :is-loading="saving"
              :disabled="saving"
              :label="t('CRM.CF_SAVE')"
            />
          </div>
        </form>
        <template v-else>
          <button
            :id="'cf-read-' + field.id"
            type="button"
            :disabled="saving"
            class="group flex flex-col gap-1 w-full min-w-0 p-2 rounded-lg text-start hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-n-brand disabled:opacity-50"
            :aria-label="t('CRM.CF_EDIT_FIELD', { name: field.name })"
            @click="edit(field)"
          >
            <span
              class="flex items-center justify-between gap-2 w-full text-xs text-n-slate-11"
            >
              {{ field.name }}
              <span
                class="i-lucide-pencil size-3 shrink-0 opacity-0 group-hover:opacity-100 group-focus-visible:opacity-100"
                aria-hidden="true"
              />
            </span>
            <span
              v-if="field.field_type === 'multiselect' && !empty(field.value)"
              class="flex flex-wrap gap-1"
            >
              <span
                v-for="option in field.value"
                :key="option"
                class="px-2 py-0.5 rounded-md bg-n-alpha-2 text-xs text-n-slate-12"
                >{{ option }}</span
              >
            </span>
            <span
              v-else
              class="block w-full min-w-0 text-sm whitespace-pre-wrap break-words text-n-slate-12"
              :class="{
                'line-clamp-3':
                  field.field_type === 'textarea' && !expandedTexts[field.id],
              }"
              >{{ display(field) }}</span
            >
          </button>
          <button
            v-if="longText(field)"
            type="button"
            :disabled="saving"
            class="ms-2 text-xs text-n-brand hover:underline"
            :aria-expanded="Boolean(expandedTexts[field.id])"
            @click="expandedTexts[field.id] = !expandedTexts[field.id]"
          >
            {{
              expandedTexts[field.id]
                ? t('CRM.SIDEBAR_LESS')
                : t('CRM.SIDEBAR_MORE')
            }}
          </button>
        </template>
      </div>
    </div>
  </section>
</template>
