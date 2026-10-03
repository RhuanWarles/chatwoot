<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { dealsAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import CrmCurrencyInput from './CrmCurrencyInput.vue';
import CrmDealExpandableText from './CrmDealExpandableText.vue';
import { brlFormatter } from './currencyHelpers';

const props = defineProps({
  dealId: { type: Number, required: true },
  deal: { type: Object, default: null },
});

const emit = defineEmits(['changed', 'dealUpdated']);
const { t, locale } = useI18n();
const fields = ref([]);
const expanded = ref(true);
const nativeDraft = ref({});
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
  expanded.value = true;
  nativeDraft.value = {
    name: props.deal?.name || '',
    description: props.deal?.description || '',
  };
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
  if (
    (props.deal && !nativeDraft.value.name.trim()) ||
    invalid.value ||
    currencies.value.some(input => input.isInvalid)
  ) {
    error.value = t('CRM.CF_INVALID');
    return;
  }
  saving.value = true;
  error.value = '';
  try {
    if (props.deal) {
      const changes = {};
      ['name', 'description'].forEach(key => {
        if (nativeDraft.value[key] !== (props.deal[key] || ''))
          changes[key] = nativeDraft.value[key];
      });
      if (Object.keys(changes).length) {
        const result = await dealsAPI.update(props.dealId, { deal: changes });
        emit('dealUpdated', result.data);
      }
    }
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
  <section class="min-w-0 border-t border-n-weak">
    <div class="flex items-center justify-between gap-2 py-3">
      <button
        type="button"
        class="flex flex-1 items-center gap-2 min-w-0 text-start text-sm font-semibold text-n-slate-12"
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
      <Button
        v-if="!loading && !editing && !error && (fields.length || deal)"
        variant="ghost"
        size="sm"
        icon="i-lucide-pencil"
        :label="t('CRM.EDIT')"
        @click="edit"
      />
    </div>
    <div
      v-show="expanded"
      :id="'deal-details-' + dealId"
      class="flex flex-col gap-3 pb-4"
    >
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
        v-if="!loading && !fields.length && !deal && !error"
        class="m-0 text-sm text-n-slate-11"
      >
        {{ t('CRM.NO_CUSTOM_FIELDS') }}
      </p>
      <form v-if="editing" class="flex flex-col gap-4" @submit.prevent="save">
        <div class="flex flex-col gap-3">
          <template v-if="deal">
            <Input
              id="deal-details-name"
              v-model="nativeDraft.name"
              :label="t('CRM.NAME')"
              :disabled="saving"
              required
            />
            <div class="flex flex-col gap-1">
              <label
                for="deal-details-description"
                class="text-xs text-n-slate-11"
                >{{ t('CRM.DESCRIPTION') }}</label
              >
              <textarea
                id="deal-details-description"
                v-model="nativeDraft.description"
                :disabled="saving"
                rows="3"
                class="w-full p-2 border rounded-lg border-n-weak bg-n-solid-1 text-sm text-n-slate-12"
              />
            </div>
          </template>
          <div
            v-for="field in fields"
            :key="field.id"
            class="flex flex-col min-w-0 gap-2"
          >
            <label
              v-if="field.field_type !== 'currency'"
              :for="'cf-' + field.id"
              class="text-xs text-n-slate-11"
            >
              <span>{{ field.name }}</span>
              <span v-if="field.required" aria-hidden="true"> *</span>
            </label>
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
        <div class="flex flex-wrap justify-end gap-2">
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
      <dl v-else-if="fields.length || deal" class="flex flex-col gap-3 m-0">
        <template v-if="deal">
          <div class="min-w-0">
            <dt class="text-xs text-n-slate-11">{{ t('CRM.NAME') }}</dt>
            <dd class="m-0 break-words text-sm text-n-slate-12">
              {{ deal.name || t('CRM.NOT_SET') }}
            </dd>
          </div>
          <div class="min-w-0">
            <dt class="text-xs text-n-slate-11">{{ t('CRM.DESCRIPTION') }}</dt>
            <dd class="m-0">
              <CrmDealExpandableText :value="deal.description || ''" />
            </dd>
          </div>
        </template>
        <div v-for="field in fields" :key="field.id" class="min-w-0">
          <dt class="text-xs text-n-slate-11">{{ field.name }}</dt>
          <dd
            class="m-0 text-sm whitespace-pre-wrap break-words text-n-slate-12"
          >
            <div
              v-if="field.field_type === 'multiselect' && !empty(field.value)"
              class="flex flex-wrap gap-1 mt-1"
            >
              <span
                v-for="option in field.value"
                :key="option"
                class="px-2 py-0.5 rounded-md bg-n-alpha-2 text-xs text-n-slate-12"
                >{{ option }}</span
              >
            </div>
            <CrmDealExpandableText
              v-else-if="field.field_type === 'textarea'"
              :value="field.value || ''"
            />
            <template v-else>{{ display(field, field.value) }}</template>
          </dd>
        </div>
      </dl>
    </div>
  </section>
</template>
