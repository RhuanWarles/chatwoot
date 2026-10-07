import { effectScope, nextTick, provide, ref } from 'vue';
import groupParticipantsAPI from 'dashboard/api/conversations/groupParticipantsAPI';
import { provideGroupMentionParticipants } from '../useGroupMentionParticipants';

vi.mock('vue', async importOriginal => ({
  ...(await importOriginal()),
  provide: vi.fn(),
}));
vi.mock('dashboard/api/conversations/groupParticipantsAPI', () => ({
  default: vi.fn(),
}));

describe('participants scoped to the conversation timeline', () => {
  let scope;
  let conversation;
  let contact;
  let accountId;
  let get;

  beforeEach(() => {
    vi.clearAllMocks();
    scope = effectScope();
    conversation = ref({ id: 36 });
    contact = ref({ identifier: '120363429365077908@g.us' });
    accountId = ref(1);
    get = vi.fn().mockResolvedValue({
      data: { participants: [{ lid: '27114849988829@lid' }] },
    });
    groupParticipantsAPI.mockReturnValue({ get });
  });
  afterEach(() => scope.stop());

  it('loads once for the conversation, independent of message count and history pagination', async () => {
    scope.run(() =>
      provideGroupMentionParticipants(conversation, contact, accountId)
    );
    await nextTick();
    conversation.value = {
      id: 36,
      messages: Array(100).fill({ content: '@27114849988829' }),
    };
    await nextTick();
    expect(get).toHaveBeenCalledTimes(1);
    expect(provide.mock.calls[0][1].value).toEqual([
      { lid: '27114849988829@lid' },
    ]);
  });

  it('does not load participants for individual conversations', async () => {
    contact.value = { identifier: '556294808700@s.whatsapp.net' };
    scope.run(() =>
      provideGroupMentionParticipants(conversation, contact, accountId)
    );
    await nextTick();
    expect(get).not.toHaveBeenCalled();
    expect(provide.mock.calls[0][1].value).toBeNull();
  });

  it('reloads when switching accounts even if display ID and group are the same', async () => {
    scope.run(() =>
      provideGroupMentionParticipants(conversation, contact, accountId)
    );
    await nextTick();
    accountId.value = 2;
    await nextTick();
    expect(get).toHaveBeenCalledTimes(2);
  });

  it('discards a late response after changing account/conversation', async () => {
    let finishOld;
    get.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          finishOld = resolve;
        })
    );
    scope.run(() =>
      provideGroupMentionParticipants(conversation, contact, accountId)
    );
    accountId.value = 2;
    conversation.value = { id: 40 };
    await nextTick();
    await nextTick();
    finishOld({ data: { participants: [{ lid: 'stale-account' }] } });
    await nextTick();
    expect(groupParticipantsAPI).toHaveBeenLastCalledWith(40);
    expect(provide.mock.calls[0][1].value).toEqual([
      { lid: '27114849988829@lid' },
    ]);
  });

  it('keeps the original rendering available when the participants API fails', async () => {
    get.mockRejectedValueOnce(new Error('Unavailable'));
    scope.run(() =>
      provideGroupMentionParticipants(conversation, contact, accountId)
    );
    await nextTick();
    expect(provide.mock.calls[0][1].value).toEqual([]);
  });
});
