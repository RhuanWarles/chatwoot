import ReplyBox from '../ReplyBox.vue';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/composables', async importOriginal => ({
  ...(await importOriginal()),
  useAlert: vi.fn(),
}));

describe('ReplyBox audio followed by text', () => {
  let composer;
  let requests;
  let dispatch;

  beforeEach(() => {
    requests = [];
    dispatch = vi.fn(async (action, payload) => {
      if (action === 'createPendingMessageAndSend') requests.push(payload);
    });
    composer = {
      ...ReplyBox.methods,
      currentChat: { id: 9, can_reply: true },
      isAPIInbox: true,
      replyType: 'reply',
      message: 'Texto depois do áudio',
      attachedFiles: [
        {
          resource: {
            file: new File(['audio'], 'clip.mp3', { type: 'audio/mpeg' }),
          },
        },
      ],
      globalConfig: { directUploadsEnabled: false },
      sender: { id: 7 },
      inReplyTo: {},
      isPrivate: false,
      isSendingAudioWithText: false,
      audioRecordingSession: 1,
      $store: { dispatch },
      $t: key => key,
      getDraftKey: () => 'draft-9',
      getCopilotAcceptedMessage: () => '',
      getMessageWithQuotedEmailText: text => text,
      sendMessageAnalyticsData: vi.fn(),
      removeFromDraft: vi.fn(),
      clearEmailField: vi.fn(),
      hideEmojiPicker: vi.fn(),
      clearMessage: vi.fn(() => {
        composer.message = '';
        composer.attachedFiles = [];
      }),
    };
    [
      'hasAudioAttachment',
      'isReplyButtonDisabled',
      'outboundDraft',
      'isEditorDisabled',
      'hasAttachments',
    ].forEach(key => {
      Object.defineProperty(composer, key, {
        get: () => ReplyBox.computed[key].call(composer),
      });
    });
    vi.clearAllMocks();
  });

  it.each(['audio/mpeg', 'audio/wav'])(
    'sends local %s first, then the captured text',
    async type => {
      composer.attachedFiles[0].resource.file = new File(['audio'], 'clip', {
        type,
      });
      await composer.confirmOnSendReply();
      expect(requests).toHaveLength(2);
      expect(requests[0].message).toBeUndefined();
      expect(requests[0].files).toHaveLength(1);
      expect(requests[1].message).toBe('Texto depois do áudio');
      expect(requests[1].files).toBeUndefined();
      expect(composer.message).toBe('');
      expect(dispatch).toHaveBeenCalledWith('draftMessages/delete', {
        key: 'draft-9',
      });
    }
  );

  it('preserves recorded voice semantics only on the audio', async () => {
    composer.attachedFiles[0].isVoiceMessage = true;
    await composer.confirmOnSendReply();
    expect(requests[0].isVoiceMessage).toBe(true);
    expect(requests[1].isVoiceMessage).toBeUndefined();
  });

  it('supports direct uploads', async () => {
    composer.globalConfig.directUploadsEnabled = true;
    composer.attachedFiles = [
      { resource: { content_type: 'audio/mpeg' }, blobSignedId: 'signed-blob' },
    ];
    await composer.confirmOnSendReply();
    expect(requests[0].files).toEqual(['signed-blob']);
    expect(requests[1].files).toBeUndefined();
  });

  it('awaits audio and text and prevents duplicate submissions', async () => {
    let resolveAudio;
    let resolveText;
    dispatch.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          resolveAudio = resolve;
        })
    );
    dispatch.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          resolveText = resolve;
        })
    );
    const sending = composer.confirmOnSendReply();
    expect(dispatch).toHaveBeenCalledTimes(1);
    composer.confirmOnSendReply();
    expect(dispatch).toHaveBeenCalledTimes(1);
    expect(composer.message).toBe('Texto depois do áudio');
    resolveAudio();
    await vi.waitFor(() => expect(dispatch).toHaveBeenCalledTimes(2));
    expect(composer.message).toBe('Texto depois do áudio');
    expect(composer.isReplyButtonDisabled).toBe(true);
    resolveText();
    await sending;
    expect(composer.isSendingAudioWithText).toBe(false);
    expect(composer.message).toBe('');
  });

  it('preserves audio and text when audio creation fails', async () => {
    dispatch.mockRejectedValueOnce(new Error('upload failed'));
    await composer.confirmOnSendReply();
    expect(dispatch).toHaveBeenCalledTimes(1);
    expect(composer.attachedFiles).toHaveLength(1);
    expect(composer.message).toBe('Texto depois do áudio');
    expect(composer.clearMessage).not.toHaveBeenCalled();
    expect(useAlert).toHaveBeenCalledWith('CONVERSATION.MESSAGE_ERROR');
    expect(composer.isSendingAudioWithText).toBe(false);
  });

  it('keeps only the text for retry if the second request fails', async () => {
    dispatch.mockResolvedValueOnce({});
    dispatch.mockRejectedValueOnce(new Error('text failed'));
    await composer.confirmOnSendReply();
    expect(composer.attachedFiles).toEqual([]);
    expect(composer.message).toBe('Texto depois do áudio');
    expect(composer.removeFromDraft).not.toHaveBeenCalled();
    await composer.confirmOnSendReply();
    expect(requests).toHaveLength(1);
    expect(requests[0].message).toBe('Texto depois do áudio');
    expect(requests[0].files).toBeUndefined();
  });

  it('keeps structured group mentions and reply only on the text', async () => {
    const participant = {
      display_name: 'Rhuan',
      jid: '5511999999999@s.whatsapp.net',
      lid: '123456@lid',
    };
    composer.message = `Olá [@Rhuan](mention://group/${encodeURIComponent(JSON.stringify(participant))})`;
    composer.inReplyTo = { id: 42 };
    await composer.confirmOnSendReply();
    expect(requests[0].contentAttributes).toBeUndefined();
    expect(requests[1].message).toBe('Olá @Rhuan');
    expect(requests[1].contentAttributes.in_reply_to).toBe(42);
    expect(requests[1].contentAttributes.whatsapp_mentions[0]).toMatchObject({
      jid: participant.jid,
      lid: participant.lid,
    });
  });

  it('does not clear a different conversation opened during sending', async () => {
    dispatch.mockImplementationOnce(async () => {
      composer.currentChat = { id: 10, can_reply: true };
      composer.message = 'Rascunho de outra conversa';
    });
    await composer.confirmOnSendReply();
    expect(requests[0].conversationId).toBe(9);
    expect(requests[0].message).toBe('Texto depois do áudio');
    expect(composer.message).toBe('Rascunho de outra conversa');
    expect(composer.clearMessage).not.toHaveBeenCalled();
  });

  it.each(['image/png', 'video/mp4', 'application/pdf'])(
    'leaves %s with text on the existing path',
    type => {
      composer.attachedFiles[0].resource.file = new File(['file'], 'file', {
        type,
      });
      composer.confirmOnSendReply();
      expect(requests).toHaveLength(1);
      expect(requests[0].message).toBe('Texto depois do áudio');
      expect(requests[0].files).toHaveLength(1);
    }
  );

  it('leaves audio alone on the existing path', () => {
    composer.message = '';
    composer.confirmOnSendReply();
    expect(requests).toHaveLength(1);
    expect(requests[0].files).toHaveLength(1);
  });

  it('leaves text alone on the existing path', () => {
    composer.attachedFiles = [];
    composer.confirmOnSendReply();
    expect(requests).toHaveLength(1);
    expect(requests[0].message).toBe('Texto depois do áudio');
    expect(requests[0].files).toBeUndefined();
  });

  it('allows another message after the sequence completes', async () => {
    await composer.confirmOnSendReply();
    composer.message = 'Próxima mensagem';
    await composer.confirmOnSendReply();
    expect(requests).toHaveLength(3);
    expect(requests[2].message).toBe('Próxima mensagem');
    expect(requests[2].files).toBeUndefined();
    expect(composer.isSendingAudioWithText).toBe(false);
  });
});
