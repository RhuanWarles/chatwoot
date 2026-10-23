<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { initializeAudioAlerts } from 'dashboard/helper/scriptHelpers';
import DashboardAudioNotificationHelper from 'dashboard/helper/AudioAlerts/DashboardAudioNotificationHelper';
import { getAlertSettings } from 'dashboard/helper/AudioAlerts/alertSettings';
import { ALERT_KIND } from 'dashboard/helper/AudioAlerts/alertPopups';
import {
  getDesktopPermission,
  requestDesktopPermission,
} from 'dashboard/helper/AudioAlerts/desktopNotification';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import AudioAlertTone from './AudioAlertTone.vue';
import AudioAlertEvent from './AudioAlertEvent.vue';
import AudioAlertCondition from './AudioAlertCondition.vue';

const store = useStore();
const getters = useStoreGetters();
const currentUser = computed(() => getters.getCurrentUser.value);
const { uiSettings, updateUISettings } = useUISettings();
const { t } = useI18n();

const i18nKeyPrefix = 'PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION';
const settings = computed(() => getAlertSettings(uiSettings.value));
const desktopPermission = ref(getDesktopPermission());

const audioAlertConditions = computed(() => [
  {
    id: 'audio1',
    label: t(`${i18nKeyPrefix}.CONDITIONS.CONDITION_ONE`),
    model: !settings.value.alwaysPlay,
    value: 'tab_is_inactive',
  },
  {
    id: 'audio2',
    label: t(`${i18nKeyPrefix}.CONDITIONS.CONDITION_TWO`),
    model: settings.value.remindUnread,
    value: 'conversations_are_read',
  },
]);

const handleAudioConfigChange = value => {
  updateUISettings(value);
  initializeAudioAlerts(currentUser.value);
  useAlert(t('PROFILE_SETTINGS.FORM.API.UPDATE_SUCCESS'));
};

// The browser only shows its permission prompt from a user gesture such as this click
const toggleDesktopAlert = async enabled => {
  if (enabled) {
    desktopPermission.value = await requestDesktopPermission();
    if (desktopPermission.value !== 'granted') {
      useAlert(t(`${i18nKeyPrefix}.CHANNELS.DESKTOP.UNAVAILABLE`));
      return;
    }
  }
  handleAudioConfigChange({ enable_desktop_alert: enabled });
};

const alertChannels = computed(() => [
  {
    key: 'popup',
    title: t(`${i18nKeyPrefix}.CHANNELS.POPUP.TITLE`),
    note: t(`${i18nKeyPrefix}.CHANNELS.POPUP.NOTE`),
    enabled: settings.value.popup,
    onChange: enabled =>
      handleAudioConfigChange({ enable_alert_popup: enabled }),
  },
  {
    key: 'sound',
    title: t(`${i18nKeyPrefix}.CHANNELS.SOUND.TITLE`),
    note: t(`${i18nKeyPrefix}.CHANNELS.SOUND.NOTE`),
    enabled: settings.value.sound,
    onChange: enabled =>
      handleAudioConfigChange({ enable_alert_sound: enabled }),
  },
  {
    key: 'desktop',
    title: t(`${i18nKeyPrefix}.CHANNELS.DESKTOP.TITLE`),
    note: t(`${i18nKeyPrefix}.CHANNELS.DESKTOP.NOTE`),
    // Shows as on only when the browser really allows it
    enabled: settings.value.desktop && desktopPermission.value === 'granted',
    onChange: toggleDesktopAlert,
  },
]);

const handleAudioAlertChange = value => {
  handleAudioConfigChange({ enable_audio_alerts: value });
};
const handleAudioAlertConditions = (id, value) => {
  if (id === 'tab_is_inactive') {
    handleAudioConfigChange({ always_play_audio_alert: !value });
  } else if (id === 'conversations_are_read') {
    handleAudioConfigChange({
      alert_if_unread_assigned_conversation_exist: value,
    });
  }
};
const handleAudioToneChange = value => {
  handleAudioConfigChange({ notification_tone: value });
};

const sendTestAlert = () => {
  DashboardAudioNotificationHelper.sendTestAlert({
    key: 'test',
    conversationId: null,
    kind: ALERT_KIND.MESSAGE,
    inboxId: null,
    contact: { name: t(`${i18nKeyPrefix}.TEST_NAME`), thumbnail: '' },
    message: {
      content: t(`${i18nKeyPrefix}.TEST_MESSAGE`),
      message_type: MESSAGE_TYPE.INCOMING,
      private: false,
    },
    summary: '',
  });
};

onMounted(() => {
  store.dispatch('userNotificationSettings/get');
});
</script>

<template>
  <div id="profile-settings-notifications" class="flex flex-col gap-6">
    <div class="flex flex-col gap-4">
      <div
        v-for="channel in alertChannels"
        :key="channel.key"
        class="flex items-start justify-between gap-4"
      >
        <div class="flex flex-col min-w-0 gap-0.5">
          <div class="text-heading-3 text-n-slate-12">{{ channel.title }}</div>
          <div class="text-body-main text-n-slate-11">{{ channel.note }}</div>
        </div>
        <Switch
          :model-value="channel.enabled"
          :aria-label="channel.title"
          @update:model-value="channel.onChange"
        />
      </div>
    </div>

    <AudioAlertTone
      :value="settings.tone"
      :label="$t(`${i18nKeyPrefix}.DEFAULT_TONE.TITLE`)"
      @change="handleAudioToneChange"
    />

    <AudioAlertEvent
      :label="$t(`${i18nKeyPrefix}.ALERT_TYPE.TITLE`)"
      :value="settings.alertEvents"
      @update="handleAudioAlertChange"
    />

    <AudioAlertCondition
      :items="audioAlertConditions"
      :label="$t(`${i18nKeyPrefix}.CONDITIONS.TITLE`)"
      @change="handleAudioAlertConditions"
    />

    <div>
      <Button
        type="button"
        slate
        faded
        icon="i-lucide-bell-ring"
        :label="$t(`${i18nKeyPrefix}.TEST`)"
        @click="sendTestAlert"
      />
    </div>
  </div>
</template>
