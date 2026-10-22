import {
  canReactToMessage,
  hasReactionTarget,
  isEvolutionInbox,
} from '../messageReactionEligibility';
import { MESSAGE_TYPES } from '../constants';

const inbox = {
  channel_type: 'Channel::Api',
  additional_attributes: { evolution_instance_name: 'account-1-instance' },
};

const key = {
  id: 'message-id',
  remoteJid: '5511999999999@s.whatsapp.net',
  fromMe: false,
};

describe('message reaction eligibility', () => {
  it('recognizes managed Evolution API inboxes', () => {
    expect(isEvolutionInbox(inbox)).toBe(true);
    expect(isEvolutionInbox({ channel_type: 'Channel::Api' })).toBe(false);
  });

  it('accepts individual WhatsApp messages with a message key', () => {
    expect(hasReactionTarget({ whatsapp_message_key: key }, '')).toBe(true);
    expect(
      canReactToMessage({
        inbox,
        contentAttributes: { whatsapp_message_key: key },
        sourceId: 'WAID:message-id',
        privateMessage: false,
        messageType: MESSAGE_TYPES.INCOMING,
      })
    ).toBe(true);
  });

  it('accepts a usable WAID fallback but rejects messages without a target', () => {
    expect(hasReactionTarget({}, 'WAID:message-id')).toBe(true);
    expect(
      canReactToMessage({
        inbox,
        contentAttributes: {},
        sourceId: '',
        privateMessage: false,
        messageType: MESSAGE_TYPES.INCOMING,
      })
    ).toBe(false);
  });

  it('keeps private and non-Evolution messages ineligible', () => {
    expect(
      canReactToMessage({
        inbox,
        contentAttributes: { whatsapp_message_key: key },
        sourceId: 'WAID:message-id',
        privateMessage: true,
        messageType: MESSAGE_TYPES.INCOMING,
      })
    ).toBe(false);
    expect(
      canReactToMessage({
        inbox: { channel_type: 'Channel::Api' },
        contentAttributes: { whatsapp_message_key: key },
        sourceId: 'WAID:message-id',
        privateMessage: false,
        messageType: MESSAGE_TYPES.INCOMING,
      })
    ).toBe(false);
  });
});
