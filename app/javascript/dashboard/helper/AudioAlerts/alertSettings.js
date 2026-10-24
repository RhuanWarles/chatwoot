export const DEFAULT_ALERT_EVENTS = 'assigned+unassigned';
export const DEFAULT_ALERT_TONE = 'ding';

// Keys the user never saved fall back to these defaults; anything saved,
// including 'none', wins.
export const getAlertSettings = uiSettings => {
  const {
    enable_audio_alerts: alertEvents,
    notification_tone: tone,
    always_play_audio_alert: alwaysPlay,
    alert_if_unread_assigned_conversation_exist: remindUnread,
    enable_alert_popup: popup,
    enable_alert_sound: sound,
    enable_desktop_alert: desktop,
  } = uiSettings || {};

  return {
    alertEvents: alertEvents || DEFAULT_ALERT_EVENTS,
    tone: tone || DEFAULT_ALERT_TONE,
    alwaysPlay: alwaysPlay ?? true,
    remindUnread: remindUnread ?? false,
    popup: popup ?? true,
    sound: sound ?? true,
    desktop: desktop ?? true,
  };
};
