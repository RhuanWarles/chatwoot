<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import { SCREENS } from 'dashboard/helper/screenAccess';

const inboxIds = defineModel('inboxIds', { type: Array, default: () => [] });
// null = the agent opens every screen their role allows; a list = only those screens.
const allowedScreens = defineModel('allowedScreens', {
  type: Array,
  default: null,
});

const { t } = useI18n();
const inboxes = useMapGetter('inboxes/getInboxes');

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
  </div>
</template>
