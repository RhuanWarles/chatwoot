import { isOwnRecordsOnlyUser } from 'dashboard/helper/permissionsHelper';

// The assignee of a conversation event: conversation payloads carry `meta.assignee`, message
// payloads nest the conversation with an `assignee_id`.
export const getEventAssigneeId = (data = {}) => {
  const conversation = data.conversation || data;
  return conversation.meta?.assignee?.id ?? conversation.assignee_id ?? null;
};

// Defense in depth: the server only sends an agent without a custom role the conversations assigned
// to them, so anything else that reaches the browser is ignored instead of being shown.
export const isForeignConversationEvent = (data, user, accountId) =>
  isOwnRecordsOnlyUser(user, accountId) &&
  getEventAssigneeId(data) !== user?.id;
