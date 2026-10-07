import { createPendingMessage } from 'dashboard/helper/commons';
import { mutations } from '../index';
import actions from '../actions';
import types from '../../../mutation-types';
import MessageApi from 'dashboard/api/inbox/message';

vi.mock('dashboard/api/inbox/message', () => ({
  default: { create: vi.fn(), retry: vi.fn() },
}));

describe('independent audio/text message reconciliation', () => {
  let state;
  let commit;

  beforeEach(() => {
    state = { allConversations: [{ id: 9, messages: [] }], selectedChatId: 9 };
    commit = (type, message) => {
      if (type === types.ADD_MESSAGE) mutations[type](state, message);
    };
    vi.clearAllMocks();
  });

  it('creates independent optimistic audio and text identities without combined content', () => {
    const audio = createPendingMessage({
      conversationId: 9,
      files: ['audio'],
      pendingMessageContent: 'Mensagem de áudio',
    });
    const text = createPendingMessage({
      conversationId: 9,
      message: 'teste depois do áudio',
    });
    commit(types.ADD_MESSAGE, audio);
    commit(types.ADD_MESSAGE, text);
    expect(audio.id).not.toBe(text.id);
    expect(audio.echo_id).toBe(audio.id);
    expect(audio.content).toBe('Mensagem de áudio');
    expect(audio.message).toBeUndefined();
    expect(text.files).toBeUndefined();
    expect(state.allConversations[0].messages).toHaveLength(2);
  });

  it.each(['response-first', 'websocket-first', 'update-before-response'])(
    'deduplicates %s with native echo_id and real id',
    order => {
      const audio = createPendingMessage({
        conversationId: 9,
        files: ['audio'],
      });
      const response = {
        id: 382,
        echo_id: audio.id,
        conversation_id: 9,
        content: null,
        attachments: [{ id: 70, file_type: 'audio' }],
        status: 'sent',
      };
      const update = { ...response };
      delete update.echo_id;
      commit(types.ADD_MESSAGE, audio);
      if (order === 'update-before-response') commit(types.ADD_MESSAGE, update);
      if (order === 'websocket-first') commit(types.ADD_MESSAGE, response);
      commit(types.ADD_MESSAGE, response);
      commit(types.ADD_MESSAGE, update);
      expect(state.allConversations[0].messages).toEqual([update]);
    }
  );

  it.each(['sent', 'delivered', 'read', 'failed'])(
    'preserves the server response status %s',
    async status => {
      const audio = createPendingMessage({
        conversationId: 9,
        files: ['audio'],
      });
      MessageApi.create.mockResolvedValue({
        data: { id: 382, echo_id: audio.id, conversation_id: 9, status },
      });
      await actions.sendMessageWithData({ commit }, audio);
      expect(state.allConversations[0].messages).toHaveLength(1);
      expect(state.allConversations[0].messages[0].status).toBe(status);
    }
  );

  it('shows a real HTTP failure and propagates the rejection', async () => {
    const audio = createPendingMessage({ conversationId: 9, files: ['audio'] });
    MessageApi.create.mockRejectedValue(new Error('upload failed'));
    await expect(
      actions.sendMessageWithData({ commit }, audio)
    ).rejects.toThrow('upload failed');
    expect(state.allConversations[0].messages[0].status).toBe('failed');
  });

  it('reconciles a later native status confirmation after a timeout', () => {
    commit(types.ADD_MESSAGE, {
      id: 382,
      conversation_id: 9,
      status: 'failed',
      content_attributes: { external_error: 'timeout' },
    });
    commit(types.ADD_MESSAGE, {
      id: 382,
      conversation_id: 9,
      status: 'sent',
      content_attributes: {},
    });
    expect(state.allConversations[0].messages).toEqual([
      { id: 382, conversation_id: 9, status: 'sent', content_attributes: {} },
    ]);
  });

  it.each(['delivered', 'read'])(
    'does not downgrade websocket %s when the HTTP response arrives late',
    status => {
      commit(types.ADD_MESSAGE, { id: 382, conversation_id: 9, status });
      commit(types.ADD_MESSAGE, {
        id: 382,
        conversation_id: 9,
        status: 'sent',
      });
      expect(state.allConversations[0].messages[0].status).toBe(status);
      commit(types.ADD_MESSAGE, {
        id: 382,
        conversation_id: 9,
        status: 'failed',
      });
      expect(state.allConversations[0].messages[0].status).toBe('failed');
    }
  );
});
