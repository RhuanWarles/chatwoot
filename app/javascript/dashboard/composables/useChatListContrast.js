/**
 * @file useChatListContrast.js
 * @description Optional theme that gives the conversation list its own background, so it stands out from the chat.
 * The choice is kept in the user settings (`chat_list_contrast`) and applied as a class on <body>.
 */

import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';

export const CONTRAST_BODY_CLASS = 'list-contrast';

export const applyChatListContrast = enabled => {
  document.body.classList.toggle(CONTRAST_BODY_CLASS, Boolean(enabled));
};

export const useChatListContrast = () => {
  const { uiSettings, updateUISettings } = useUISettings();
  const { t } = useI18n();

  const enabled = computed(() => Boolean(uiSettings.value.chat_list_contrast));

  watch(enabled, value => applyChatListContrast(value), { immediate: true });

  const setEnabled = async value => {
    try {
      await updateUISettings({ chat_list_contrast: Boolean(value) });
      useAlert(
        t(
          'PROFILE_SETTINGS.FORM.INTERFACE_SECTION.LIST_CONTRAST.UPDATE_SUCCESS'
        )
      );
    } catch (error) {
      useAlert(
        t('PROFILE_SETTINGS.FORM.INTERFACE_SECTION.LIST_CONTRAST.UPDATE_ERROR')
      );
    }
  };

  return { enabled, setEnabled };
};

export default useChatListContrast;
