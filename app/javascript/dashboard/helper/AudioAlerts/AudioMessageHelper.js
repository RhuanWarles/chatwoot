export const getAssignee = message => message?.conversation?.assignee_id;
export const isConversationUnassigned = message => !getAssignee(message);
export const isConversationAssignedToMe = (message, currentUserId) =>
  getAssignee(message) === currentUserId;
// A contact or bot can share a numeric id with the agent, so the sender type must match too
export const isMessageFromCurrentUser = (message, currentUserId) =>
  message?.sender?.type === 'user' && message.sender.id === currentUserId;
