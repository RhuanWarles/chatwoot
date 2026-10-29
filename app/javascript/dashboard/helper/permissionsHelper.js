export const hasPermissions = (
  requiredPermissions = [],
  availablePermissions = []
) => {
  return requiredPermissions.some(permission =>
    availablePermissions.includes(permission)
  );
};

export const getCurrentAccount = ({ accounts } = {}, accountId = null) => {
  return accounts.find(account => Number(account.id) === Number(accountId));
};

export const getUserPermissions = (user, accountId) => {
  const currentAccount = getCurrentAccount(user, accountId) || {};
  return currentAccount.permissions || [];
};

// Screens an administrator limited this person to; null means everything their role allows.
export const getAllowedScreens = (user, accountId) => {
  const currentAccount = getCurrentAccount(user, accountId) || {};
  return currentAccount.allowed_screens ?? null;
};

export const getUserRole = (user, accountId) => {
  const currentAccount = getCurrentAccount(user, accountId) || {};
  if (currentAccount.custom_role_id) {
    return 'custom_role';
  }

  return currentAccount.role || 'agent';
};

// An agent without a custom role only works with the records that belong to them: the conversations
// assigned to them and the CRM cards they own. `getUserRole` reports 'custom_role' when a role id is set.
export const isOwnRecordsOnlyUser = (user, accountId) =>
  Boolean(user?.accounts) && getUserRole(user, accountId) === 'agent';

/**
 * Filters and transforms items based on user permissions.
 *
 * @param {Object} items - An object containing items to be filtered.
 * @param {Array} userPermissions - Array of permissions the user has.
 * @param {Function} getPermissions - Function to extract required permissions from an item.
 * @param {Function} [transformItem] - Optional function to transform each item after filtering.
 * @returns {Array} Filtered and transformed items.
 */
export const filterItemsByPermission = (
  items,
  userPermissions,
  getPermissions,
  transformItem = (key, item) => ({ key, ...item })
) => {
  // Helper function to check if an item has the required permissions
  const hasRequiredPermissions = item => {
    const requiredPermissions = getPermissions(item);
    return (
      requiredPermissions.length === 0 ||
      hasPermissions(requiredPermissions, userPermissions)
    );
  };

  return Object.entries(items)
    .filter(([, item]) => hasRequiredPermissions(item)) // Keep only items with required permissions
    .map(([key, item]) => transformItem(key, item)); // Transform each remaining item
};
