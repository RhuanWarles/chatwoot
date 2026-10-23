import { canEditMessage } from '../messageEditEligibility';
import { MESSAGE_TYPES } from '../constants';

const inbox = {
  channel_type: 'Channel::Api',
  additional_attributes: { evolution_instance_name: 'account-1-instance' },
};

const key = {
  id: 'message-id',
  remoteJid: '5511999999999@s.whatsapp.net',
  fromMe: true,
};

describe('message edit eligibility', () => {
  const attributes = { whatsapp_message_key: key };
  const eligibleMessage = {
    inbox,
    messageType: MESSAGE_TYPES.OUTGOING,
    contentType: 'text',
    content: 'Original message',
    contentAttributes: attributes,
    privateMessage: false,
    sourceId: 'WAID:message-id',
    status: 'sent',
    createdAt: Math.floor(Date.now() / 1000) - 60,
  };

  it('allows recent outgoing Evolution text messages', () => {
    expect(canEditMessage(eligibleMessage)).toBe(true);
  });

  it('rejects inbound, private, deleted and failed messages', () => {
    expect(
      canEditMessage({
        ...eligibleMessage,
        messageType: MESSAGE_TYPES.INCOMING,
      })
    ).toBe(false);
    expect(canEditMessage({ ...eligibleMessage, privateMessage: true })).toBe(
      false
    );
    expect(
      canEditMessage({
        ...eligibleMessage,
        contentAttributes: { ...attributes, deleted: true },
      })
    ).toBe(false);
    expect(canEditMessage({ ...eligibleMessage, status: 'failed' })).toBe(
      false
    );
  });

  it('rejects API messages that are not managed by Evolution', () => {
    expect(
      canEditMessage({
        ...eligibleMessage,
        inbox: { channel_type: 'Channel::Api' },
      })
    ).toBe(false);
  });

  it('rejects messages outside WhatsApp editing window', () => {
    expect(
      canEditMessage({
        ...eligibleMessage,
        createdAt: Math.floor(Date.now() / 1000) - 16 * 60,
      })
    ).toBe(false);
  });
});
