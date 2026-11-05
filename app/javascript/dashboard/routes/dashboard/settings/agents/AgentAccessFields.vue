<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { customFieldsAPI } from 'dashboard/api/crm';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import { SCREENS } from 'dashboard/helper/screenAccess';
import {
  FIELD_GROUPS,
  STATIC_FIELDS,
  customFieldKey,
  fieldLabelKey,
} from 'dashboard/helper/fieldAccess';

const inboxIds = defineModel('inboxIds', { type: Array, default: () => [] });
// null = the agent opens every screen their role allows; a list = only those screens.
const allowedScreens = defineModel('allowedScreens', {
  type: Array,
  default: null,
});
// null = the agent sees every field; a list = the keys of the fields hidden from them.
const hiddenFields = defineModel('hiddenFields', {
  type: Array,
  default: null,
});
const canResolveConversations = defineModel('canResolveConversations', {
  type: Boolean,
  default: true,
});

const { t } = useI18n();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');
const attributes = useMapGetter('attributes/getAttributes');
const attributesByModel = useMapGetter('attributes/getAttributesByModel');
const dealFields = ref([]);

const inboxOptions = computed(() =>
  inboxes.value.map(({ id, name }) => ({ value: id, label: name }))
);
const restricted = computed(() => Array.isArray(allowedScreens.value));
const screenOptions = computed(() =>
  SCREENS.map(screen => ({
    value: screen,
    label: t(`AGENT_MGMT.ACCESS.SCREENS.${screen.toUpperCase()}`),
  }))
);
const hasNoScreen = computed(
  () => restricted.value && allowedScreens.value.length === 0
);

const setRestricted = value => {
  allowedScreens.value = value ? [...SCREENS] : null;
};
const toggleScreen = (screen, checked) => {
  const current = allowedScreens.value ?? [];
  allowedScreens.value = checked
    ? [...current, screen]
    : current.filter(item => item !== screen);
};

const customRows = {
  contact: () =>
    attributesByModel.value('contact_attribute').map(attribute => ({
      key: customFieldKey('contact', attribute.attribute_key),
      label: attribute.attribute_display_name,
    })),
  conversation: () =>
    attributesByModel.value('conversation_attribute').map(attribute => ({
      key: customFieldKey('conversation', attribute.attribute_key),
      label: attribute.attribute_display_name,
    })),
  deal: () =>
    dealFields.value.map(field => ({
      key: customFieldKey('deal', field.key),
      label: field.name,
    })),
};

// Every field an administrator can hide: the fixed ones of each record and its custom fields.
const fieldGroups = computed(() =>
  FIELD_GROUPS.map(group => ({
    group,
    title: t(`AGENT_MGMT.ACCESS.FIELDS.GROUPS.${group.toUpperCase()}`),
    rows: [
      ...STATIC_FIELDS[group].map(key => ({
        key,
        label: t(fieldLabelKey(key)),
      })),
      ...customRows[group](),
    ],
  }))
);

const hiddenKeys = computed(() => hiddenFields.value ?? []);
const isVisible = key => !hiddenKeys.value.includes(key);
const setVisible = (key, visible) => {
  const next = visible
    ? hiddenKeys.value.filter(item => item !== key)
    : [...hiddenKeys.value, key];
  hiddenFields.value = next.length ? next : null;
};

onMounted(async () => {
  if (!attributes.value.length) store.dispatch('attributes/get');
  try {
    dealFields.value = (await customFieldsAPI.get()).data.filter(
      field => field.active !== false
    );
  } catch (error) {
    dealFields.value = [];
  }
});
</script>

<template>
  <div class="flex flex-col w-full gap-4 mb-4">
    <div class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('AGENT_MGMT.ACCESS.INBOXES.LABEL') }}
      </span>
      <TagMultiSelectComboBox
        v-model="inboxIds"
        :options="inboxOptions"
        :placeholder="t('AGENT_MGMT.ACCESS.INBOXES.PLACEHOLDER')"
      />
      <span class="text-xs text-n-slate-11">
        {{ t('AGENT_MGMT.ACCESS.INBOXES.HELP') }}
      </span>
    </div>

    <fieldset class="flex flex-col gap-2 p-0 m-0 border-0" data-test="screens">
      <legend class="mb-1 text-sm font-medium text-n-slate-12">
        {{ t('AGENT_MGMT.ACCESS.SCREENS.LABEL') }}
      </legend>
      <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-12">
        <input
          type="radio"
          class="mb-0"
          name="agent-screens"
          :checked="!restricted"
          @change="setRestricted(false)"
        />
        {{ t('AGENT_MGMT.ACCESS.SCREENS.ALL') }}
      </label>
      <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-12">
        <input
          type="radio"
          class="mb-0"
          name="agent-screens"
          :checked="restricted"
          @change="setRestricted(true)"
        />
        {{ t('AGENT_MGMT.ACCESS.SCREENS.CHOOSE') }}
      </label>
      <div
        v-if="restricted"
        class="grid grid-cols-1 gap-2 p-3 rounded-lg sm:grid-cols-2 bg-n-alpha-2"
      >
        <label
          v-for="option in screenOptions"
          :key="option.value"
          class="flex items-center gap-2 mb-0 text-sm text-n-slate-12"
        >
          <Checkbox
            :model-value="allowedScreens.includes(option.value)"
            @update:model-value="toggleScreen(option.value, $event)"
          />
          {{ option.label }}
        </label>
      </div>
      <span v-if="hasNoScreen" class="text-xs text-n-ruby-11" role="alert">
        {{ t('AGENT_MGMT.ACCESS.SCREENS.AT_LEAST_ONE') }}
      </span>
      <span v-else class="text-xs text-n-slate-11">
        {{ t('AGENT_MGMT.ACCESS.SCREENS.HELP') }}
      </span>
    </fieldset>

    <fieldset class="flex flex-col gap-2 p-0 m-0 border-0" data-test="fields">
      <legend class="mb-1 text-sm font-medium text-n-slate-12">
        {{ t('AGENT_MGMT.ACCESS.FIELDS.LABEL') }}
      </legend>
      <span class="text-xs text-n-slate-11">
        {{ t('AGENT_MGMT.ACCESS.FIELDS.HELP') }}
      </span>
      <div
        v-for="section in fieldGroups"
        :key="section.group"
        class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-2"
        :data-test="`fields-${section.group}`"
      >
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ section.title }}
        </span>
        <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
          <label
            v-for="row in section.rows"
            :key="row.key"
            class="flex items-center gap-2 mb-0 text-sm text-n-slate-12"
          >
            <Checkbox
              :model-value="isVisible(row.key)"
              :data-test="row.key"
              @update:model-value="setVisible(row.key, $event)"
            />
            {{ row.label }}
          </label>
        </div>
      </div>
    </fieldset>

    <fieldset class="flex flex-col gap-2 p-0 m-0 border-0" data-test="resolve">
      <legend class="mb-1 text-sm font-medium text-n-slate-12">
        {{ t('AGENT_MGMT.ACCESS.RESOLVE.LABEL') }}
      </legend>
      <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-12">
        <Checkbox v-model="canResolveConversations" data-test="can-resolve" />
        {{ t('AGENT_MGMT.ACCESS.RESOLVE.CHECKBOX') }}
      </label>
      <span class="text-xs text-n-slate-11">
        {{ t('AGENT_MGMT.ACCESS.RESOLVE.HELP') }}
      </span>
    </fieldset>
  </div>
</template>
