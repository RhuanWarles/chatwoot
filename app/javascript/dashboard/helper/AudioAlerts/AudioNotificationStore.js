import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions';
import {
  getUserPermissions,
  getUserRole,
} from 'dashboard/helper/permissionsHelper';
import { applyRoleFilter } from 'dashboard/store/modules/conversations/helpers';
import wootConstants from 'dashboard/constants/globals';

class AudioNotificationStore {
  constructor(store) {
    this.store = store;
  }

  hasUnreadConversation = () => {
    const mineConversation = this.store.getters.getMineChats({
      assigneeType: 'me',
      status: 'open',
    });

    return mineConversation.some(conv => conv.unread_count > 0);
  };

  isMessageFromPendingConversation = (message = {}) => {
    const { conversation_id: conversationId } = message || {};
    if (!conversationId) return false;

    const activeConversation =
      this.store.getters.getConversationById(conversationId);
    return activeConversation?.status === wootConstants.STATUS_TYPE.PENDING;
  };

  isMessageFromCurrentConversation = message => {
    return this.store.getters.getSelectedChat?.id === message.conversation_id;
  };

  hasConversationPermission = (user, message) => {
    const currentAccountId = this.store.getters.getCurrentAccountId;
    // Get the user permissions for the current account
    const userPermissions = getUserPermissions(user, currentAccountId);
    // Check if the user has the required permissions
    const hasRequiredPermission = [...ROLES, ...CONVERSATION_PERMISSIONS].some(
      permission => userPermissions.includes(permission)
    );
    if (!hasRequiredPermission || !message) return hasRequiredPermission;

    // Events reach every inbox member; a custom role may only see unassigned or own conversations
    const assigneeId = message.conversation?.assignee_id;
    const conversation = {
      meta: { assignee: assigneeId ? { id: assigneeId } : null },
    };
    return applyRoleFilter(
      conversation,
      getUserRole(user, currentAccountId),
      userPermissions,
      user.id
    );
  };
}

export default AudioNotificationStore;
