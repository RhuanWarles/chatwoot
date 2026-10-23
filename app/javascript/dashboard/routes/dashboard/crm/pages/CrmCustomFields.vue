<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import { customFieldsAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownBody from 'dashboard/components-next/dropdown-menu/base/DropdownBody.vue';
import DropdownContainer from 'dashboard/components-next/dropdown-menu/base/DropdownContainer.vue';
import DropdownItem from 'dashboard/components-next/dropdown-menu/base/DropdownItem.vue';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();

const FIELD_TYPES = [
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

const createDraft = field => ({
  id: field?.id,
  name: field?.name || '',
  field_type: field?.field_type || 'text',
  required: field?.required || false,
  active: field?.active ?? true,
  options: [...(field?.options || [])],
});

const fields = ref([]);
const editor = ref(null);
const saving = ref(false);
const loading = ref(false);
const error = ref('');
const search = ref('');
const statusFilter = ref('all');
const draft = ref(createDraft());
const activeMenuId = ref(null);
const menuToggles = new Map();

provideDropdownTeleport();

const typeLabels = computed(() => ({
  text: t('CRM.CUSTOM_FIELD_TYPES.TEXT'),
  textarea: t('CRM.CUSTOM_FIELD_TYPES.TEXTAREA'),
  number: t('CRM.CUSTOM_FIELD_TYPES.NUMBER'),
  currency: t('CRM.CUSTOM_FIELD_TYPES.CURRENCY'),
  date: t('CRM.CUSTOM_FIELD_TYPES.DATE'),
  datetime: t('CRM.CUSTOM_FIELD_TYPES.DATETIME'),
  boolean: t('CRM.CUSTOM_FIELD_TYPES.BOOLEAN'),
  select: t('CRM.CUSTOM_FIELD_TYPES.SELECT'),
  multiselect: t('CRM.CUSTOM_FIELD_TYPES.MULTISELECT'),
}));

const typeDescriptions = computed(() => ({
  text: t('CRM.CUSTOM_FIELD_TYPE_DESCRIPTIONS.TEXT'),
  textarea: t('CRM.CUSTOM_FIELD_TYPE_DESCRIPTIONS.TEXTAREA'),
  number: t('CRM.CUSTOM_FIELD_TYPE_DESCRIPTIONS.NUMBER'),
  currency: t('CRM.CUSTOM_FIELD_TYPE_DESCRIPTIONS.CURRENCY'),
  date: t('CRM.CUSTOM_FIELD_TYPE_DESCRIPTIONS.DATE'),
  datetime: t('CRM.CUSTOM_FIELD_TYPE_DESCRIPTIONS.DATETIME'),
  boolean: t('CRM.CUSTOM_FIELD_TYPE_DESCRIPTIONS.BOOLEAN'),
  select: t('CRM.CUSTOM_FIELD_TYPE_DESCRIPTIONS.SELECT'),
  multiselect: t('CRM.CUSTOM_FIELD_TYPE_DESCRIPTIONS.MULTISELECT'),
}));

const typeOptions = computed(() =>
  FIELD_TYPES.map(value => ({ value, label: typeLabels.value[value] }))
);

const statusOptions = computed(() => [
  { value: 'all', label: t('CRM.CUSTOM_FIELD_STATUS_FILTER.ALL') },
  { value: 'active', label: t('CRM.CUSTOM_FIELD_STATUS_FILTER.ACTIVE') },
  {
    value: 'inactive',
    label: t('CRM.CUSTOM_FIELD_STATUS_FILTER.INACTIVE'),
  },
]);

const isOptionsField = computed(() =>
  ['select', 'multiselect'].includes(draft.value.field_type)
);

const selectedTypeDescription = computed(
  () => typeDescriptions.value[draft.value.field_type]
);

const hasFilters = computed(
  () => Boolean(search.value.trim()) || statusFilter.value !== 'all'
);

const filteredFields = computed(() => {
  const query = search.value.trim().toLowerCase();

  return fields.value.filter(field => {
    const matchesSearch = !query || field.name.toLowerCase().includes(query);
    const matchesStatus =
      statusFilter.value === 'all' ||
      (statusFilter.value === 'active' && field.active !== false) ||
      (statusFilter.value === 'inactive' && field.active === false);

    return matchesSearch && matchesStatus;
  });
});

const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    fields.value = (await customFieldsAPI.get()).data;
  } catch {
    error.value = t('CRM.CF_LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};

const openNew = () => {
  error.value = '';
  draft.value = createDraft();
  editor.value.open();
};

const edit = field => {
  error.value = '';
  draft.value = createDraft(field);
  editor.value.open();
};

const addOption = () => {
  draft.value.options.push('');
};

const removeOption = index => {
  draft.value.options.splice(index, 1);
};

const moveOption = (index, direction) => {
  const nextIndex = index + direction;
  if (nextIndex < 0 || nextIndex >= draft.value.options.length) return;

  const options = draft.value.options;
  [options[index], options[nextIndex]] = [options[nextIndex], options[index]];
};

const save = async () => {
  if (!draft.value.name.trim() || saving.value) return;

  saving.value = true;
  error.value = '';
  try {
    const payload = {
      custom_field: {
        name: draft.value.name.trim(),
        field_type: draft.value.field_type,
        required: draft.value.required,
        active: draft.value.active,
        options: draft.value.options
          .map(option => option.trim())
          .filter(Boolean),
      },
    };

    if (draft.value.id) {
      await customFieldsAPI.update(draft.value.id, payload);
    } else {
      await customFieldsAPI.create(payload);
    }

    editor.value.close();
    await load();
  } catch {
    error.value = t('CRM.CF_SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};

const toggle = async field => {
  try {
    await customFieldsAPI.update(field.id, {
      custom_field: { active: field.active === false },
    });
    await load();
  } catch {
    error.value = t('CRM.CF_SAVE_ERROR');
  }
};

const remove = async field => {
  /* eslint-disable no-alert */
  const confirmed = window.confirm(
    t('CRM.CONFIRM_DELETE_CUSTOM_FIELD', { name: field.name })
  );
  /* eslint-enable no-alert */
  if (!confirmed) {
    return;
  }

  try {
    await customFieldsAPI.delete(field.id);
    await load();
  } catch {
    error.value = t('CRM.CF_SAVE_ERROR');
  }
};

const toggleMenu = (fieldId, isOpen, toggleDropdown) => {
  menuToggles.set(fieldId, toggleDropdown);

  if (isOpen) {
    toggleDropdown();
    activeMenuId.value = null;
    return;
  }

  if (activeMenuId.value && activeMenuId.value !== fieldId) {
    menuToggles.get(activeMenuId.value)?.();
  }

  activeMenuId.value = fieldId;
  toggleDropdown();
};

const closeMenu = fieldId => {
  if (activeMenuId.value === fieldId) {
    activeMenuId.value = null;
  }
};

const handleMenuAction = (field, action) => {
  closeMenu(field.id);
  if (action === 'toggle') toggle(field);
  if (action === 'delete') remove(field);
};

onMounted(load);
</script>

<template>
  <main
    class="flex h-full min-h-0 w-full min-w-0 flex-1 flex-col overflow-auto bg-n-background p-4 sm:p-6"
  >
    <div class="mx-auto flex w-full max-w-6xl flex-col gap-6">
      <header
        class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"
      >
        <div class="min-w-0">
          <h1 class="text-xl font-semibold text-n-slate-12">
            {{ t('CRM.CUSTOM_FIELDS_TITLE') }}
          </h1>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('CRM.CUSTOM_FIELDS_SUBTITLE') }}
          </p>
        </div>
        <Button
          class="shrink-0"
          size="sm"
          :label="t('CRM.NEW_FIELD')"
          icon="i-lucide-plus"
          @click="openNew"
        />
      </header>

      <div
        class="flex flex-col gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-3 sm:flex-row sm:items-end"
      >
        <div class="min-w-0 flex-1">
          <Input
            v-model="search"
            :placeholder="t('CRM.CUSTOM_FIELD_SEARCH_PLACEHOLDER')"
            :aria-label="t('CRM.CUSTOM_FIELD_SEARCH_PLACEHOLDER')"
            custom-input-class="!ps-9"
          >
            <template #prefix>
              <span
                class="pointer-events-none absolute start-3 top-3.5 i-lucide-search size-4 text-n-slate-10"
                aria-hidden="true"
              />
            </template>
          </Input>
        </div>
        <div class="w-full sm:w-48">
          <label class="mb-1 block text-label-small text-n-slate-11">
            {{ t('CRM.CUSTOM_FIELD_STATUS') }}
          </label>
          <ComboBox v-model="statusFilter" :options="statusOptions" />
        </div>
      </div>

      <p
        v-if="error"
        class="rounded-lg bg-n-ruby-3 px-3 py-2 text-sm text-n-ruby-11"
      >
        {{ error }}
      </p>

      <div
        v-if="loading"
        class="flex items-center justify-center rounded-xl border border-n-weak bg-n-solid-1 px-4 py-12 text-sm text-n-slate-11"
      >
        {{ t('CRM.CF_LOADING') }}
      </div>

      <div
        v-else-if="filteredFields.length"
        role="table"
        class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
        :aria-label="t('CRM.CUSTOM_FIELDS_TITLE')"
      >
        <div
          role="row"
          class="hidden grid-cols-[minmax(0,2fr)_minmax(8rem,1fr)_minmax(7rem,1fr)_minmax(7rem,1fr)_auto] gap-4 border-b border-n-weak bg-n-alpha-1 px-4 py-3 text-label-small font-medium text-n-slate-11 sm:grid"
        >
          <span>{{ t('CRM.CUSTOM_FIELD_NAME') }}</span>
          <span>{{ t('CRM.CUSTOM_FIELD_TYPE') }}</span>
          <span>{{ t('CRM.CUSTOM_FIELD_REQUIRED') }}</span>
          <span>{{ t('CRM.CUSTOM_FIELD_STATUS') }}</span>
          <span class="text-end">{{ t('CRM.CUSTOM_FIELD_ACTIONS') }}</span>
        </div>

        <div
          v-for="field in filteredFields"
          :key="field.id"
          role="row"
          class="grid grid-cols-1 gap-3 border-b border-n-weak px-4 py-4 last:border-b-0 sm:grid-cols-[minmax(0,2fr)_minmax(8rem,1fr)_minmax(7rem,1fr)_minmax(7rem,1fr)_auto] sm:items-center sm:gap-4"
        >
          <div role="cell" class="min-w-0">
            <p class="truncate text-sm font-medium text-n-slate-12">
              {{ field.name }}
            </p>
            <p class="mt-1 truncate text-xs text-n-slate-10">
              {{ field.key || t('CRM.NOT_AVAILABLE') }}
            </p>
          </div>
          <div
            role="cell"
            class="flex items-center gap-2 text-sm text-n-slate-12"
          >
            <span
              class="i-lucide-brackets size-4 shrink-0 text-n-slate-10"
              aria-hidden="true"
            />
            <span>{{ typeLabels[field.field_type] || field.field_type }}</span>
          </div>
          <div
            role="cell"
            class="flex items-center gap-2 text-sm text-n-slate-12"
          >
            <span class="text-xs text-n-slate-10 sm:hidden">{{
              t('CRM.CUSTOM_FIELD_REQUIRED')
            }}</span>
            {{ field.required ? t('CRM.CF_YES') : t('CRM.CF_NO') }}
          </div>
          <div role="cell">
            <span
              class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium"
              :class="
                field.active !== false
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              {{ field.active !== false ? t('CRM.ACTIVE') : t('CRM.INACTIVE') }}
            </span>
          </div>
          <div
            role="cell"
            class="flex items-center justify-start gap-1 sm:justify-end"
          >
            <Button
              variant="ghost"
              size="sm"
              :label="t('CRM.EDIT')"
              @click="edit(field)"
            />
            <DropdownContainer @close="closeMenu(field.id)">
              <template #trigger="{ toggle: toggleDropdown }">
                <Button
                  variant="ghost"
                  size="sm"
                  icon="i-lucide-ellipsis-vertical"
                  :aria-label="t('CRM.CUSTOM_FIELD_MORE_ACTIONS')"
                  :aria-expanded="activeMenuId === field.id"
                  @click="
                    toggleMenu(
                      field.id,
                      activeMenuId === field.id,
                      toggleDropdown
                    )
                  "
                />
              </template>
              <DropdownBody class="min-w-44">
                <DropdownItem
                  :label="
                    field.active !== false
                      ? t('CRM.DEACTIVATE')
                      : t('CRM.ACTIVATE')
                  "
                  :icon="
                    field.active !== false ? 'i-lucide-eye-off' : 'i-lucide-eye'
                  "
                  :click="() => handleMenuAction(field, 'toggle')"
                />
                <DropdownItem
                  :label="t('CRM.DELETE')"
                  icon="i-lucide-trash-2"
                  :click="() => handleMenuAction(field, 'delete')"
                  class="text-n-ruby-11"
                />
              </DropdownBody>
            </DropdownContainer>
          </div>
        </div>
      </div>

      <div
        v-else
        class="flex flex-col items-center justify-center rounded-xl border border-dashed border-n-weak bg-n-solid-1 px-6 py-14 text-center"
      >
        <span
          class="mb-3 i-lucide-sliders-horizontal size-8 text-n-slate-9"
          aria-hidden="true"
        />
        <p class="mb-1 text-sm font-medium text-n-slate-12">
          {{
            hasFilters
              ? t('CRM.CUSTOM_FIELD_NO_RESULTS')
              : t('CRM.NO_CUSTOM_FIELDS')
          }}
        </p>
        <p v-if="!hasFilters" class="mb-4 text-sm text-n-slate-11">
          {{ t('CRM.CUSTOM_FIELD_EMPTY_HELP') }}
        </p>
        <Button
          v-if="!hasFilters"
          size="sm"
          :label="t('CRM.NEW_FIELD')"
          icon="i-lucide-plus"
          @click="openNew"
        />
      </div>
    </div>

    <Dialog
      ref="editor"
      :title="draft.id ? t('CRM.EDIT_CUSTOM_FIELD') : t('CRM.NEW_CUSTOM_FIELD')"
      :description="t('CRM.CUSTOM_FIELD_DIALOG_DESCRIPTION')"
      :cancel-button-label="t('CRM.CF_CANCEL')"
      :confirm-button-label="
        draft.id ? t('CRM.CF_SAVE') : t('CRM.CREATE_CUSTOM_FIELD')
      "
      :disable-confirm-button="!draft.name.trim()"
      :is-loading="saving"
      show-close-button
      overflow-y-auto
      @confirm="save"
    >
      <div class="flex flex-col gap-5">
        <Input
          v-model="draft.name"
          :label="t('CRM.CUSTOM_FIELD_NAME')"
          :placeholder="t('CRM.CUSTOM_FIELD_NAME_PLACEHOLDER')"
          autofocus
        />

        <div class="flex flex-col gap-1">
          <label class="text-heading-3 text-n-slate-12">
            {{ t('CRM.CUSTOM_FIELD_TYPE') }}
          </label>
          <ComboBox
            v-model="draft.field_type"
            :options="typeOptions"
            :placeholder="t('CRM.CUSTOM_FIELD_TYPE_PLACEHOLDER')"
          />
          <p class="mt-1 text-xs text-n-slate-11">
            {{ selectedTypeDescription }}
          </p>
        </div>

        <label
          class="flex items-start gap-3 rounded-lg border border-n-weak p-3"
        >
          <Checkbox v-model:model-value="draft.required" />
          <span class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CRM.CUSTOM_FIELD_REQUIRED') }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ t('CRM.CUSTOM_FIELD_REQUIRED_HELP') }}
            </span>
          </span>
        </label>

        <div
          v-if="isOptionsField"
          class="flex flex-col gap-3 rounded-lg border border-n-weak p-3"
        >
          <div>
            <p class="text-sm font-medium text-n-slate-12">
              {{ t('CRM.CUSTOM_FIELD_OPTIONS') }}
            </p>
            <p class="mt-1 text-xs text-n-slate-11">
              {{ t('CRM.CUSTOM_FIELD_OPTIONS_HELP') }}
            </p>
          </div>
          <div
            v-for="(_, index) in draft.options"
            :key="index"
            class="flex items-end gap-1"
          >
            <Input
              v-model="draft.options[index]"
              class="min-w-0 flex-1"
              :label="t('CRM.CUSTOM_FIELD_OPTION') + ' ' + (index + 1)"
            />
            <Button
              variant="ghost"
              color="ruby"
              size="sm"
              icon="i-lucide-trash-2"
              :aria-label="t('CRM.CUSTOM_FIELD_REMOVE_OPTION')"
              @click="removeOption(index)"
            />
            <Button
              variant="ghost"
              size="sm"
              icon="i-lucide-chevron-up"
              :aria-label="t('CRM.CUSTOM_FIELD_MOVE_OPTION_UP')"
              :disabled="index === 0"
              @click="moveOption(index, -1)"
            />
            <Button
              variant="ghost"
              size="sm"
              icon="i-lucide-chevron-down"
              :aria-label="t('CRM.CUSTOM_FIELD_MOVE_OPTION_DOWN')"
              :disabled="index === draft.options.length - 1"
              @click="moveOption(index, 1)"
            />
          </div>
          <Button
            class="self-start"
            variant="ghost"
            size="sm"
            icon="i-lucide-plus"
            :label="t('CRM.ADD_OPTION')"
            @click="addOption"
          />
        </div>
      </div>
    </Dialog>
  </main>
</template>
