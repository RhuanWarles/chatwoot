import { getters } from '../../conversation/getters';

describe('#getters', () => {
  it('getConversation', () => {
    const state = {
      conversations: {
        1: {
          content: 'hello',
        },
      },
    };
    expect(getters.getConversation(state)).toEqual({
      1: {
        content: 'hello',
      },
    });
  });

  it('getIsCreating', () => {
    const state = { uiFlags: { isCreating: true } };
    expect(getters.getIsCreating(state)).toEqual(true);
  });

  it('getConversationSize', () => {
    const state = {
      conversations: {
        1: {
          content: 'hello',
        },
      },
    };
    expect(getters.getConversationSize(state)).toEqual(1);
  });

  it('getEarliestMessage', () => {
    const state = {
      conversations: {
        1: {
          content: 'hello',
        },
        2: {
          content: 'hello1',
        },
      },
    };
    expect(getters.getEarliestMessage(state)).toEqual({
      content: 'hello',
    });
  });

  it('uiFlags', () => {
    const state = {
      uiFlags: {
        allMessagesLoaded: false,
        isFetchingList: false,
        isAgentTyping: false,
      },
    };
    expect(getters.getAllMessagesLoaded(state)).toEqual(false);
    expect(getters.getIsFetchingList(state)).toEqual(false);
    expect(getters.getIsAgentTyping(state)).toEqual(false);
  });

  it('getGroupedConversation', () => {
    expect(
      getters.getGroupedConversation({
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 0,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 0,
          },
          3: {
            id: 3,
            content: 'Hey',
            created_at: 1574092218,
            message_type: 1,
          },
          4: {
            id: 4,
            content: 'Hey',
            created_at: 1576340623,
          },
          5: {
            id: 5,
            content: 'How may I help you',
            created_at: 1576340626,
          },
        },
      })
    ).toEqual([
      {
        date: '2019-11-18',
        messages: [
          {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            showAvatar: false,
            message_type: 0,
          },
          {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            showAvatar: true,
            message_type: 0,
          },
          {
            id: 3,
            content: 'Hey',
            created_at: 1574092218,
            showAvatar: true,
            message_type: 1,
          },
        ],
      },
      {
        date: '2019-12-14',
        messages: [
          {
            id: 4,
            content: 'Hey',
            created_at: 1576340623,
            showAvatar: false,
          },
          {
            id: 5,
            content: 'How may I help you',
            created_at: 1576340626,
            showAvatar: true,
          },
        ],
      },
    ]);

    expect(
      getters.getGroupedConversation({
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 0,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 0,
          },
          3: {
            id: 3,
            content: 'Hey',
            created_at: 1574092218,
            message_type: 1,
          },
          4: {
            id: 4,
            content: 'Hey',
            created_at: 1576340623,
          },
          5: {
            id: 5,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            content_attributes: {
              submitted_values: [{ name: 'text', value: 'sample text' }],
            },
          },
          6: {
            id: 6,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
          },
          7: {
            id: 7,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            content_attributes: {
              submitted_values: [{ name: 'text', value: 'sample text' }],
            },
          },
        },
      })
    ).toEqual([
      {
        date: '2019-11-18',
        messages: [
          {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            showAvatar: false,
            message_type: 0,
          },
          {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            showAvatar: true,
            message_type: 0,
          },
          {
            id: 3,
            content: 'Hey',
            created_at: 1574092218,
            showAvatar: true,
            message_type: 1,
          },
        ],
      },
      {
        date: '2019-12-14',
        messages: [
          {
            id: 4,
            content: 'Hey',
            created_at: 1576340623,
            showAvatar: true,
          },
          {
            id: 5,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            content_attributes: {
              submitted_values: [{ name: 'text', value: 'sample text' }],
            },
            showAvatar: false,
          },
          {
            id: 6,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            showAvatar: true,
          },
          {
            id: 7,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            content_attributes: {
              submitted_values: [{ name: 'text', value: 'sample text' }],
            },

            showAvatar: false,
          },
        ],
      },
    ]);
  });

  it('groups messages by the America/Sao_Paulo calendar day', () => {
    const groupedConversation = getters.getGroupedConversation({
      conversations: {
        1: {
          id: 1,
          content: 'Late in Brazil',
          created_at: Math.floor(
            new Date('2026-10-27T02:30:00.000Z').getTime() / 1000
          ),
          message_type: 0,
        },
        2: {
          id: 2,
          content: 'New day in Brazil',
          created_at: Math.floor(
            new Date('2026-10-27T03:30:00.000Z').getTime() / 1000
          ),
          message_type: 0,
        },
      },
    });

    expect(groupedConversation).toHaveLength(2);
    expect(groupedConversation[0].messages).toHaveLength(1);
    expect(groupedConversation[1].messages).toHaveLength(1);
  });

  describe('getUnreadMessageCount returns', () => {
    it('0 if there are no messages and last seen is undefined', () => {
      const state = {
        conversations: {},
        meta: {
          userLastSeenAt: undefined,
        },
      };
      expect(getters.getUnreadMessageCount(state)).toEqual(0);
    });

    it('0 if there are no messages and last seen is present', () => {
      const state = {
        conversations: {},
        meta: {
          userLastSeenAt: Date.now(),
        },
      };
      expect(getters.getUnreadMessageCount(state)).toEqual(0);
    });

    it('unread count if there are messages and last seen is before messages created-at', () => {
      const state = {
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 1,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 1,
          },
        },
        meta: {
          userLastSeenAt: 1474075964,
        },
      };
      expect(getters.getUnreadMessageCount(state)).toEqual(2);
    });

    it('unread count if there are messages and last seen is after messages created-at', () => {
      const state = {
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 1,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 1,
          },
          3: {
            id: 3,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 0,
          },
        },
        meta: {
          userLastSeenAt: 1674075964,
        },
      };
      expect(getters.getUnreadMessageCount(state)).toEqual(0);
    });
  });

  describe('getUnreadTextMessages returns', () => {
    it('no messages if there are no messages and last seen is undefined', () => {
      const state = {
        conversations: {},
        meta: {
          userLastSeenAt: undefined,
        },
      };
      expect(
        getters.getUnreadTextMessages(state, { getUnreadMessageCount: 0 })
      ).toEqual([]);
    });

    it('0 if there are no messages and last seen is present', () => {
      const state = {
        conversations: {},
        meta: {
          userLastSeenAt: Date.now(),
        },
      };
      expect(
        getters.getUnreadTextMessages(state, { getUnreadMessageCount: 0 })
      ).toEqual([]);
    });

    it('only unread text messages from agent if there are messages and last seen is before messages created-at', () => {
      const state = {
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 1,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 0,
          },
        },
      };
      expect(
        getters.getUnreadTextMessages(state, { getUnreadMessageCount: 1 })
      ).toEqual([
        {
          id: 1,
          content: 'Thanks for the help',
          created_at: 1574075964,
          message_type: 1,
        },
      ]);
    });

    it('unread messages omitting seen messages ', () => {
      const state = {
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 1,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1674075965,
            message_type: 1,
          },
          3: {
            id: 3,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 0,
          },
        },
        meta: {
          userLastSeenAt: 1674075964,
        },
      };
      expect(
        getters.getUnreadTextMessages(state, { getUnreadMessageCount: 1 })
      ).toEqual([
        {
          id: 2,
          content: 'Yes, It makes sense',
          created_at: 1674075965,
          message_type: 1,
        },
      ]);
    });
  });

  it('getMessageCount', () => {
    const state = {
      conversations: {
        1: {
          content: 'hey, how are you?',
        },
      },
    };
    expect(getters.getMessageCount(state)).toEqual(1);
  });

  it('getLastMessage', () => {
    const state = {
      conversations: {
        1: {
          id: 1,
          content: 'Thanks for the help',
          created_at: 1574075964,
          message_type: 1,
        },
        2: {
          id: 2,
          content: 'Yes, It makes sense',
          created_at: 1574092218,
          message_type: 1,
        },
        3: {
          id: 3,
          content: 'Yes, It makes sense',
          created_at: 1574092218,
          message_type: 0,
        },
      },
      meta: {
        userLastSeenAt: 1674075964,
      },
    };
    expect(getters.getLastMessage(state).id).toEqual(3);
  });
});
