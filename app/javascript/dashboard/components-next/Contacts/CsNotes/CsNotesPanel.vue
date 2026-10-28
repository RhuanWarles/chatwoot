<script setup>
import { ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useCsNotes } from 'dashboard/composables/useCsNotes';
import CsNotesAPI from 'dashboard/api/csNotes';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CsFieldInput from './CsFieldInput.vue';
import CsFieldsManager from './CsFieldsManager.vue';

const props = defineProps({
  contactId: { type: [String, Number], required: true },
});

const { t } = useI18n();
const { loaded, canAccess, fields, load } = useCsNotes();

const values = ref({});
const loadingValues = ref(false);
const managing = ref(false);

const loadValues = async contactId => {
  values.value = {};
  if (!contactId || !canAccess.value) return;

  loadingValues.value = true;
  try {
    const { data } = await CsNotesAPI.getValues(contactId);
    // A slower answer for a contact the person already left must not replace the current one.
    if (String(contactId) === String(props.contactId)) {
      values.value = data.field_values ?? {};
    }
  } catch {
    useAlert(t('CS_NOTES.LOAD_ERROR'));
  } finally {
    loadingValues.value = false;
  }
};

const save = async (field, value) => {
  const contactId = props.contactId;
  try {
    const { data } = await CsNotesAPI.saveValues(contactId, {
      [field.attribute_key]: value,
    });
    if (String(contactId) === String(props.contactId)) {
      values.value = data.field_values ?? {};
    }
  } catch {
    useAlert(t('CS_NOTES.SAVE_ERROR'));
  }
};

onMounted(async () => {
  await load();
  loadValues(props.contactId);
});

watch(
  () => props.contactId,
  contactId => loadValues(contactId)
);
</script>

<template>
  <div class="flex flex-col gap-3 p-3" data-test="cs-notes">
    <div v-if="!loaded || loadingValues" class="flex justify-center py-4">
      <Spinner />
    </div>
    <template v-else-if="canAccess">
      <p v-if="!fields.length" class="m-0 text-xs text-n-slate-11">
        {{ t('CS_NOTES.NO_FIELDS') }}
      </p>
      <div
        v-for="field in fields"
        :key="field.id"
        class="flex flex-col gap-1"
        data-test="cs-note-field"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ field.attribute_display_name }}
        </span>
        <CsFieldInput
          :field="field"
          :model-value="values[field.attribute_key] ?? ''"
          @commit="value => save(field, value)"
        />
      </div>
      <Button
        type="button"
        variant="ghost"
        color="slate"
        size="sm"
        :icon="managing ? 'i-lucide-chevron-up' : 'i-lucide-settings-2'"
        :label="managing ? t('CS_NOTES.CLOSE_MANAGER') : t('CS_NOTES.MANAGE')"
        data-test="cs-manage"
        @click="managing = !managing"
      />
      <CsFieldsManager v-if="managing" />
    </template>
  </div>
</template>
