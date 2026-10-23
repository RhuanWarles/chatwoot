import { MESSAGE_TYPE } from 'shared/constants/messages';

export const ALERT_KIND = {
  MESSAGE: 'message',
  HANDOFF: 'handoff',
};
export const MAX_ALERT_POPUPS = 4;
export const ALERT_POPUP_DURATION_MS = {
  [ALERT_KIND.MESSAGE]: 8000,
  [ALERT_KIND.HANDOFF]: 20000,
};

// Prefix of the private note written by the AI handoff tool
// (Saas::AiAgents::BuiltinTools::HANDOFF_NOTE_PREFIX). If it ever changes, the
// popup simply shows the whole note.
const HANDOFF_NOTE_PREFIX = /^Transferido pela IA\. Resumo: /;
const NO_CONTACT = { name: '', thumbnail: '' };

export const isAiHandoffNote = message =>
  message.private === true && message.content_attributes?.ai_handoff === true;

export const buildMessageAlert = message => {
  const { sender } = message;
  // Only a contact identifies the conversation; a note carries its author instead
  const isFromContact =
    message.message_type === MESSAGE_TYPE.INCOMING && Boolean(sender);

  return {
    key: String(message.conversation_id),
    conversationId: message.conversation_id,
    kind: ALERT_KIND.MESSAGE,
    inboxId: message.inbox_id,
    contact: isFromContact
      ? { name: sender.name || '', thumbnail: sender.thumbnail || '' }
      : NO_CONTACT,
    message,
    summary: '',
  };
};

export const buildHandoffNoteAlert = message => ({
  key: String(message.conversation_id),
  conversationId: message.conversation_id,
  kind: ALERT_KIND.HANDOFF,
  inboxId: message.inbox_id,
  contact: NO_CONTACT,
  message: null,
  summary: (message.content || '').replace(HANDOFF_NOTE_PREFIX, ''),
});

export const buildHandoffEventAlert = conversation => {
  const sender = conversation.meta?.sender;

  return {
    key: String(conversation.id),
    conversationId: conversation.id,
    kind: ALERT_KIND.HANDOFF,
    inboxId: conversation.inbox_id,
    contact: { name: sender?.name || '', thumbnail: sender?.thumbnail || '' },
    message: null,
    summary: '',
  };
};

// The alert's own snapshot first, then whatever the store learned later
// (conversation.updated arrives right after an AI handoff).
export const resolveAlertContact = (alert, conversation) => {
  const stored = conversation?.meta?.sender;

  return {
    name: alert.contact.name || stored?.name || '',
    thumbnail: alert.contact.thumbnail || stored?.thumbnail || '',
  };
};

export const upsertAlertPopup = (popups, alert, max = MAX_ALERT_POPUPS) => {
  const current = popups.find(popup => popup.key === alert.key);
  const next = current
    ? {
        ...alert,
        // A handoff stays a handoff; later messages refresh the preview and the counter
        kind: current.kind === ALERT_KIND.HANDOFF ? current.kind : alert.kind,
        contact: alert.contact.name ? alert.contact : current.contact,
        summary: alert.summary || current.summary,
        message: alert.message || current.message,
        count: current.count + 1,
        revision: current.revision + 1,
      }
    : { ...alert, count: 1, revision: 0 };

  return [...popups.filter(popup => popup.key !== alert.key), next].slice(-max);
};

export const dismissAlertPopup = (popups, key) =>
  popups.filter(popup => popup.key !== key);
