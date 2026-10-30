import {
  getEventAssigneeId,
  isForeignConversationEvent,
} from '../ownRecordsScope';

const accountId = 1;
const userWith = (role, customRoleId = null) => ({
  id: 7,
  accounts: [{ id: accountId, role, custom_role_id: customRoleId }],
});

describe('ownRecordsScope', () => {
  describe('getEventAssigneeId', () => {
    it('reads the assignee of a conversation payload', () => {
      expect(getEventAssigneeId({ id: 1, meta: { assignee: { id: 7 } } })).toBe(
        7
      );
    });

    it('reads the assignee of the conversation nested in a message payload', () => {
      expect(getEventAssigneeId({ conversation: { assignee_id: 7 } })).toBe(7);
    });

    it('is null for an unassigned conversation', () => {
      expect(getEventAssigneeId({ id: 1, meta: { assignee: null } })).toBe(
        null
      );
      expect(getEventAssigneeId({ conversation: { assignee_id: null } })).toBe(
        null
      );
    });
  });

  describe('isForeignConversationEvent', () => {
    const mine = { id: 1, meta: { assignee: { id: 7 } } };
    const someoneElses = { id: 2, meta: { assignee: { id: 9 } } };
    const unassigned = { id: 3, meta: { assignee: null } };

    it('lets an agent without a custom role see only their own conversations', () => {
      const agent = userWith('agent');

      expect(isForeignConversationEvent(mine, agent, accountId)).toBe(false);
      expect(isForeignConversationEvent(someoneElses, agent, accountId)).toBe(
        true
      );
      expect(isForeignConversationEvent(unassigned, agent, accountId)).toBe(
        true
      );
    });

    it('applies to message payloads too', () => {
      const agent = userWith('agent');

      expect(
        isForeignConversationEvent(
          { conversation: { assignee_id: 9 } },
          agent,
          accountId
        )
      ).toBe(true);
    });

    it('never ignores events for administrators and custom roles', () => {
      expect(
        isForeignConversationEvent(
          someoneElses,
          userWith('administrator'),
          accountId
        )
      ).toBe(false);
      expect(
        isForeignConversationEvent(
          someoneElses,
          userWith('agent', 4),
          accountId
        )
      ).toBe(false);
    });
  });
});
