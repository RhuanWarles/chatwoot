import { MESSAGE_TYPE } from 'shared/constants/messages';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import { CONTENT_TYPES } from 'dashboard/components-next/message/constants';
import { showBadgeOnFavicon } from './faviconHelper';
import { initFaviconSwitcher } from './faviconHelper';

import { EVENT_TYPES } from 'dashboard/routes/dashboard/settings/profile/constants.js';
import GlobalStore from 'dashboard/store';
import AudioNotificationStore from './AudioNotificationStore';
import {
  isConversationAssignedToMe,
  isConversationUnassigned,
  isMessageFromCurrentUser,
} from './AudioMessageHelper';
import {
  buildHandoffEventAlert,
  buildHandoffNoteAlert,
  buildMessageAlert,
  isAiHandoffNote,
} from './alertPopups';
import WindowVisibilityHelper from './WindowVisibilityHelper';
import { useAlert } from 'dashboard/composables';

const NOTIFICATION_TIME = 30000;
const ALERT_DURATION = 10000;
// The AI handoff note and conversation.bot_handoff announce the same handoff, so it alerts once
const HANDOFF_DEDUP_MS = 20000;
const ALERT_PATH_PREFIX = '/audio/dashboard/';
const DEFAULT_TONE = 'ding';
const DEFAULT_ALERT_TYPE = ['none'];

export class DashboardAudioNotificationHelper {
  constructor(store) {
    if (!store) {
      throw new Error('store is required');
    }
    this.store = new AudioNotificationStore(store);

    this.notificationConfig = {
      audioAlertType: DEFAULT_ALERT_TYPE,
      playAlertOnlyWhenHidden: true,
      alertIfUnreadConversationExist: false,
    };

    this.recurringNotificationTimer = null;

    // conversation key -> when its handoff last alerted
    this.recentHandoffs = new Map();

    this.audioConfig = {
      audio: null,
      tone: DEFAULT_TONE,
      hasSentSoundPermissionsRequest: false,
    };

    this.currentUser = null;
  }

  intializeAudio = () => {
    const resourceUrl = `${ALERT_PATH_PREFIX}${this.audioConfig.tone}.mp3`;
    this.audioConfig.audio = new Audio(resourceUrl);
    return this.audioConfig.audio.load();
  };

  // Resolves false only when the browser blocked playback
  playAudioAlert = async () => {
    const { soundEnabled = true } = this.notificationConfig;
    if (!soundEnabled) return true;

    try {
      await this.audioConfig.audio.play();
      return true;
    } catch (error) {
      if (
        error.name === 'NotAllowedError' &&
        !this.hasSentSoundPermissionsRequest
      ) {
        this.hasSentSoundPermissionsRequest = true;
        useAlert(
          'PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.SOUND_PERMISSION_ERROR',
          { usei18n: true, duration: ALERT_DURATION }
        );
      }
      return false;
    }
  };

  set = ({
    currentUser,
    alwaysPlayAudioAlert,
    alertIfUnreadConversationExist,
    audioAlertType = DEFAULT_ALERT_TYPE,
    audioAlertTone = DEFAULT_TONE,
    popupEnabled = true,
    soundEnabled = true,
    desktopEnabled = true,
  }) => {
    this.notificationConfig = {
      ...this.notificationConfig,
      audioAlertType: audioAlertType.split('+').filter(Boolean),
      playAlertOnlyWhenHidden: !alwaysPlayAudioAlert,
      alertIfUnreadConversationExist: alertIfUnreadConversationExist,
      popupEnabled,
      soundEnabled,
      desktopEnabled,
    };

    this.currentUser = currentUser;

    const previousAudioTone = this.audioConfig.tone;
    this.audioConfig = {
      ...this.audioConfig,
      tone: audioAlertTone,
    };

    if (!this.audioConfig.audio || previousAudioTone !== audioAlertTone) {
      this.intializeAudio();
    }

    initFaviconSwitcher();
    this.clearRecurringTimer();
    this.playAudioEvery30Seconds();
  };

  shouldPlayAlert = () => {
    if (this.notificationConfig.playAlertOnlyWhenHidden) {
      return !WindowVisibilityHelper.isWindowVisible();
    }
    return true;
  };

  executeRecurringNotification = () => {
    if (this.store.hasUnreadConversation() && this.shouldPlayAlert()) {
      this.playAudioAlert();
      showBadgeOnFavicon();
    }
    this.resetRecurringTimer();
  };

  clearRecurringTimer = () => {
    if (this.recurringNotificationTimer) {
      clearTimeout(this.recurringNotificationTimer);
    }
  };

  resetRecurringTimer = () => {
    this.clearRecurringTimer();
    this.recurringNotificationTimer = setTimeout(
      this.executeRecurringNotification,
      NOTIFICATION_TIME
    );
  };

  playAudioEvery30Seconds = () => {
    const { audioAlertType, alertIfUnreadConversationExist } =
      this.notificationConfig;

    //  Audio alert is disabled dismiss the timer
    if (audioAlertType.includes('none')) return;

    // If unread conversation flag is disabled, dismiss the timer
    if (!alertIfUnreadConversationExist) return;

    this.resetRecurringTimer();
  };

  shouldNotifyOnMessage = message => {
    const { audioAlertType } = this.notificationConfig;
    if (audioAlertType.includes('none')) return false;
    if (audioAlertType.includes('all')) return true;

    const assignedToMe = isConversationAssignedToMe(
      message,
      this.currentUser.id
    );
    const isUnassigned = isConversationUnassigned(message);

    const shouldPlayAudio = [];

    if (
      audioAlertType.includes(EVENT_TYPES.ASSIGNED) ||
      audioAlertType.includes('mine')
    ) {
      shouldPlayAudio.push(assignedToMe);
    }
    if (audioAlertType.includes(EVENT_TYPES.UNASSIGNED)) {
      shouldPlayAudio.push(isUnassigned);
    }
    if (audioAlertType.includes(EVENT_TYPES.NOTME)) {
      shouldPlayAudio.push(!isUnassigned && !assignedToMe);
    }

    return shouldPlayAudio.some(Boolean);
  };

  // Returns whether the alert fired
  triggerAlert = (message, alert) => {
    if (!this.store.hasConversationPermission(this.currentUser, message)) {
      return false;
    }
    if (!this.shouldNotifyOnMessage(message)) return false;

    const isVisible = WindowVisibilityHelper.isWindowVisible();
    if (isVisible && this.store.isMessageFromCurrentConversation(message)) {
      return false;
    }

    const { popupEnabled = true, desktopEnabled = true } =
      this.notificationConfig;
    if (isVisible) {
      // The popup is for someone looking at the dashboard
      if (popupEnabled) emitter.emit(BUS_EVENTS.SHOW_ALERT_POPUP, alert);
      if (this.notificationConfig.playAlertOnlyWhenHidden) return true;
    }

    const playing = this.playAudioAlert();
    if (!isVisible) {
      showBadgeOnFavicon();
      // The system notification makes its own sound only when the browser blocked ours
      if (desktopEnabled) {
        playing.then(played =>
          emitter.emit(BUS_EVENTS.SHOW_DESKTOP_ALERT, { alert, silent: played })
        );
      }
    }
    this.playAudioEvery30Seconds();
    return true;
  };

  // The AI handoff note and conversation.bot_handoff both end here
  alertHandoff = (message, alert) => {
    const now = Date.now();
    this.recentHandoffs.forEach((alertedAt, key) => {
      const elapsed = now - alertedAt;
      if (elapsed < 0 || elapsed >= HANDOFF_DEDUP_MS) {
        this.recentHandoffs.delete(key);
      }
    });
    if (this.recentHandoffs.has(alert.key)) return;

    // Only a handoff that really alerted blocks its twin signal
    if (this.triggerAlert(message, alert)) {
      this.recentHandoffs.set(alert.key, now);
    }
  };

  onConversationBotHandoff = conversation => {
    // Adapt the handoff once to the existing audio-filter contract. Bot IDs
    // must not be treated as human assignees, even when their IDs overlap.
    this.alertHandoff(
      {
        conversation_id: conversation.id,
        conversation: {
          assignee_id:
            conversation.meta?.assignee_type === 'User'
              ? conversation.meta.assignee?.id
              : null,
        },
      },
      buildHandoffEventAlert(conversation)
    );
  };

  onAiHandoffNote = message => {
    // On pending conversations conversation.bot_handoff alerts once the conversation opens
    if (this.store.isMessageFromPendingConversation(message)) return;

    this.alertHandoff(message, buildHandoffNoteAlert(message));
  };

  onNewMessage = message => {
    // The AI handoff note IS the handoff alert on open conversations
    if (isAiHandoffNote(message)) {
      this.onAiHandoffNote(message);
      return;
    }

    // Captain notes are context, not requests for attention. Only the dedicated
    // handoff event alerts agents, regardless of when its explanatory note arrives.
    if (message.private && message.sender?.type === 'captain_assistant') return;

    // If the conversation status is pending, then dismiss the alert
    // This case is common for all audio event types
    if (this.store.isMessageFromPendingConversation(message)) {
      return;
    }

    // If the message is sent by the current user then dismiss the alert
    if (isMessageFromCurrentUser(message, this.currentUser.id)) {
      return;
    }

    // If the message type is not incoming or private, then dismiss the alert
    const { message_type: messageType, private: isPrivate } = message;
    if (messageType !== MESSAGE_TYPE.INCOMING && !isPrivate) {
      return;
    }

    // The call widget already rings for calls and a call message has no text to preview
    if (message.content_type === CONTENT_TYPES.VOICE_CALL) return;

    this.triggerAlert(message, buildMessageAlert(message));
  };

  // Profile 'Send test alert' button; bypasses scope and window state on purpose
  sendTestAlert = async alert => {
    const { popupEnabled = true, desktopEnabled = true } =
      this.notificationConfig;
    if (popupEnabled) emitter.emit(BUS_EVENTS.SHOW_ALERT_POPUP, alert);

    const played = await this.playAudioAlert();
    if (desktopEnabled) {
      emitter.emit(BUS_EVENTS.SHOW_DESKTOP_ALERT, { alert, silent: played });
    }
  };
}

export default new DashboardAudioNotificationHelper(GlobalStore);
