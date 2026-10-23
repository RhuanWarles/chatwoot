import { MESSAGE_TYPES } from './constants.js';

const whatsappJid = /^[\d:-]+@(g\.us|s\.whatsapp\.net|lid)$/;

export const isEvolutionInbox = inbox => {
  const channelType = inbox?.channel_type || inbox?.channelType;
  const attributes =
    inbox?.additional_attributes || inbox?.additionalAttributes || {};
  return (
    channelType === 'Channel::Api' &&
    !!(attributes.evolution_instance_name || attributes.evolutionInstanceName)
  );
};

export const hasReactionTarget = (contentAttributes = {}, sourceId = '') => {
  const key =
    contentAttributes.whatsapp_message_key ||
    contentAttributes.whatsappMessageKey;
  const remoteJids = [
    key?.remoteJid,
    key?.remote_jid,
    key?.remoteJidAlt,
    key?.remote_jid_alt,
  ];
  const hasMessageKey =
    key &&
    typeof key === 'object' &&
    typeof key.id === 'string' &&
    key.id.length > 0 &&
    remoteJids.some(jid => typeof jid === 'string' && whatsappJid.test(jid)) &&
    [true, false].includes(key.fromMe ?? key.from_me);
  const normalizedSourceId =
    typeof sourceId === 'string' ? sourceId.replace(/^WAID:/, '') : '';

  return hasMessageKey || normalizedSourceId.length > 0;
};

export const canReactToMessage = ({
  inbox,
  contentAttributes,
  sourceId,
  privateMessage,
  messageType,
}) =>
  isEvolutionInbox(inbox) &&
  hasReactionTarget(contentAttributes, sourceId) &&
  !privateMessage &&
  !contentAttributes?.deleted &&
  [MESSAGE_TYPES.INCOMING, MESSAGE_TYPES.OUTGOING].includes(messageType);
