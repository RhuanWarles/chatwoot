<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import FormSelect from 'v3/components/Form/Select.vue';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { setColorTheme } from 'dashboard/helper/themeHelper';

defineProps({
  label: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();

const selectedValue = ref(
  LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_SCHEME) || 'auto'
);

const options = computed(() => [
  {
    value: 'light',
    label: t(
      'PROFILE_SETTINGS.FORM.INTERFACE_SECTION.APPEARANCE.OPTIONS.LIGHT'
    ),
  },
  {
    value: 'dark',
    label: t('PROFILE_SETTINGS.FORM.INTERFACE_SECTION.APPEARANCE.OPTIONS.DARK'),
  },
  {
    value: 'auto',
    label: t(
      'PROFILE_SETTINGS.FORM.INTERFACE_SECTION.APPEARANCE.OPTIONS.SYSTEM'
    ),
  },
]);

const onChange = value => {
  selectedValue.value = value;
  LocalStorage.set(LOCAL_STORAGE_KEYS.COLOR_SCHEME, value);
  setColorTheme(window.matchMedia('(prefers-color-scheme: dark)').matches);
};
</script>

<template>
  <div class="flex gap-2 justify-between w-full items-start">
    <div>
      <label class="text-n-gray-12 font-medium leading-6 text-sm">
        {{ label }}
      </label>
      <p class="text-n-gray-11">
        {{ description }}
      </p>
    </div>
    <FormSelect
      :model-value="selectedValue"
      name="appearance"
      spacing="compact"
      class="min-w-28 mt-px"
      :options="options"
      label=""
      @update:model-value="onChange"
    >
      <option
        v-for="option in options"
        :key="option.value"
        :value="option.value"
        :selected="option.value === selectedValue"
      >
        {{ option.label }}
      </option>
    </FormSelect>
  </div>
</template>
