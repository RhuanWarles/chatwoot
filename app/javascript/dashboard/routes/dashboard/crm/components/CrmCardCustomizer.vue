<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { customFieldsAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import { CARD_FIELDS, useCrmCardConfig } from './cardConfig';

const { t } = useI18n();
const { fields, customFieldIds, save, reset } = useCrmCardConfig();
const customFields = ref([]);
const loading = ref(false);
const error = ref(false);

const toggleField = key =>
  save(
    CARD_FIELDS.map(field => field.key).filter(item =>
      item === key ? !fields.value.includes(item) : fields.value.includes(item)
    ),
    customFieldIds.value
  );
// Rebuilt from the loaded active definitions, so ids of deleted or deactivated fields drop out.
const toggleCustomField = id =>
  save(
    fields.value,
    customFields.value
      .map(field => field.id)
      .filter(item =>
        item === id
          ? !customFieldIds.value.includes(item)
          : customFieldIds.value.includes(item)
      )
  );

onMounted(async () => {
  loading.value = true;
  try {
    customFields.value = (await customFieldsAPI.get()).data.filter(
      field => field.active
    );
  } catch {
    error.value = true;
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div
    class="flex flex-col gap-4 w-full sm:w-80 max-h-96 p-4 overflow-y-auto text-n-slate-12"
  >
    <fieldset class="flex flex-col gap-2 min-w-0 p-0 m-0 border-0">
      <legend class="mb-2 text-sm font-medium">
        {{ t('CRM.CARD_FIELDS_TITLE') }}
      </legend>
      <label
        v-for="field in CARD_FIELDS"
        :key="field.key"
        class="flex items-center gap-2 text-sm text-n-slate-12"
      >
        <input
          type="checkbox"
          :checked="fields.includes(field.key)"
          @change="toggleField(field.key)"
        />
        {{ t(`CRM.CARD_FIELDS.${field.key.toUpperCase()}`) }}
      </label>
    </fieldset>
    <fieldset class="flex flex-col gap-2 min-w-0 p-0 m-0 border-0">
      <legend class="mb-2 text-sm font-medium">
        {{ t('CRM.CUSTOM_FIELDS_TITLE') }}
      </legend>
      <p v-if="loading" class="m-0 text-sm text-n-slate-11">
        {{ t('CRM.CF_LOADING') }}
      </p>
      <p v-else-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
        {{ t('CRM.CF_LOAD_ERROR') }}
      </p>
      <p v-else-if="!customFields.length" class="m-0 text-sm text-n-slate-11">
        {{ t('CRM.NO_CUSTOM_FIELDS') }}
      </p>
      <label
        v-for="field in customFields"
        :key="field.id"
        class="flex items-center gap-2 text-sm text-n-slate-12"
      >
        <input
          type="checkbox"
          :checked="customFieldIds.includes(field.id)"
          @change="toggleCustomField(field.id)"
        />
        <span class="min-w-0 truncate">{{ field.name }}</span>
      </label>
    </fieldset>
    <p class="m-0 text-xs text-n-slate-11">
      {{ t('CRM.CARD_FIELDS_HELP') }}
    </p>
    <Button
      type="button"
      variant="ghost"
      color="slate"
      size="sm"
      class="self-start"
      :label="t('CRM.CARD_RESET')"
      @click="reset"
    />
  </div>
</template>
