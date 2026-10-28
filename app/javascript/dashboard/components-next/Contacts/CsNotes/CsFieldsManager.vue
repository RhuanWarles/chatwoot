<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useCsNotes } from 'dashboard/composables/useCsNotes';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const FIELD_TYPES = [
  'text',
  'number',
  'currency',
  'percent',
  'link',
  'date',
  'list',
  'checkbox',
];

const { t } = useI18n();
const {
  fields,
  canManage,
  teamId,
  addField,
  renameField,
  removeField,
  saveTeam,
} = useCsNotes();
const teams = useMapGetter('teams/getTeams');

const name = ref('');
const type = ref('text');
const options = ref('');
const adding = ref(false);
const confirmingId = ref(null);

const typeOptions = computed(() =>
  FIELD_TYPES.map(value => ({
    value,
    label: t(`CS_NOTES.TYPES.${value.toUpperCase()}`),
  }))
);

const teamOptions = computed(() => [
  { value: '', label: t('CS_NOTES.TEAM_NONE') },
  ...teams.value.map(team => ({ value: team.id, label: team.name })),
]);

const listValues = computed(() =>
  options.value
    .split('\n')
    .map(value => value.trim())
    .filter(Boolean)
);

const canAdd = computed(
  () =>
    name.value.trim() &&
    !adding.value &&
    (type.value !== 'list' || listValues.value.length > 0)
);

const add = async () => {
  if (!canAdd.value) return;

  adding.value = true;
  try {
    await addField({
      attribute_display_name: name.value.trim(),
      attribute_display_type: type.value,
      ...(type.value === 'list' ? { attribute_values: listValues.value } : {}),
    });
    name.value = '';
    options.value = '';
    type.value = 'text';
  } catch {
    useAlert(t('CS_NOTES.ADD_ERROR'));
  } finally {
    adding.value = false;
  }
};

const rename = async (field, value) => {
  const trimmed = value.trim();
  if (!trimmed || trimmed === field.attribute_display_name) return;

  try {
    await renameField(field.id, trimmed);
  } catch {
    useAlert(t('CS_NOTES.RENAME_ERROR'));
  }
};

const remove = async field => {
  try {
    await removeField(field.id);
  } catch {
    useAlert(t('CS_NOTES.DELETE_ERROR'));
  } finally {
    confirmingId.value = null;
  }
};

const changeTeam = async value => {
  try {
    await saveTeam(value === '' ? null : value);
    useAlert(t('CS_NOTES.TEAM_SAVED'));
  } catch {
    useAlert(t('CS_NOTES.TEAM_ERROR'));
  }
};
</script>

<template>
  <div
    class="flex flex-col gap-4 p-3 rounded-lg bg-n-alpha-1"
    data-test="cs-fields-manager"
  >
    <div v-if="canManage" class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('CS_NOTES.TEAM_LABEL') }}
      </span>
      <Select
        class="!w-full"
        :model-value="teamId ?? ''"
        :options="teamOptions"
        :aria-label="t('CS_NOTES.TEAM_LABEL')"
        data-test="cs-team-select"
        @update:model-value="changeTeam"
      />
      <p class="m-0 text-xs text-n-slate-11">{{ t('CS_NOTES.TEAM_HELP') }}</p>
    </div>

    <div class="flex flex-col gap-2">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('CS_NOTES.FIELDS_TITLE') }}
      </span>
      <p v-if="!fields.length" class="m-0 text-xs text-n-slate-11">
        {{ t('CS_NOTES.NO_FIELDS') }}
      </p>
      <div
        v-for="field in fields"
        :key="field.id"
        class="flex items-center gap-2"
        data-test="cs-field-row"
      >
        <Input
          class="flex-1"
          :model-value="field.attribute_display_name"
          :data-test="`cs-field-name-${field.attribute_key}`"
          @blur="rename(field, $event.target.value)"
        />
        <span class="text-xs shrink-0 text-n-slate-11">
          {{
            t(`CS_NOTES.TYPES.${field.attribute_display_type.toUpperCase()}`)
          }}
        </span>
        <Button
          v-if="confirmingId !== field.id"
          type="button"
          variant="ghost"
          color="ruby"
          size="xs"
          icon="i-lucide-trash-2"
          :title="t('CS_NOTES.DELETE')"
          :aria-label="t('CS_NOTES.DELETE')"
          data-test="cs-field-delete"
          @click="confirmingId = field.id"
        />
        <Button
          v-else
          type="button"
          color="ruby"
          size="xs"
          :label="t('CS_NOTES.DELETE_CONFIRM')"
          data-test="cs-field-delete-confirm"
          @click="remove(field)"
        />
      </div>
    </div>

    <form class="flex flex-col gap-2" @submit.prevent="add">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('CS_NOTES.ADD_TITLE') }}
      </span>
      <Input
        v-model="name"
        :placeholder="t('CS_NOTES.NAME_PLACEHOLDER')"
        data-test="cs-new-name"
      />
      <Select
        v-model="type"
        class="!w-full"
        :options="typeOptions"
        :aria-label="t('CS_NOTES.TYPE_LABEL')"
        data-test="cs-new-type"
      />
      <TextArea
        v-if="type === 'list'"
        v-model="options"
        :max-length="2000"
        :placeholder="t('CS_NOTES.OPTIONS_PLACEHOLDER')"
        data-test="cs-new-options"
      />
      <Button
        type="submit"
        size="sm"
        :label="t('CS_NOTES.ADD')"
        :disabled="!canAdd"
        :is-loading="adding"
        data-test="cs-add-field"
      />
    </form>
  </div>
</template>
