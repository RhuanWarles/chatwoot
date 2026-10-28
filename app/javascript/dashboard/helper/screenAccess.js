// Screens an administrator can switch off for an agent. They are the sections of the dashboard an agent can open
// (the AI hub, reports, campaigns and settings are administrator-only anyway). Keep in sync with AccountUser::SCREENS.
export const SCREENS = [
  'inbox',
  'conversations',
  'calls',
  'contacts',
  'companies',
  'crm',
  'help_center',
];

// Where each screen starts, to send the person somewhere they can go when the page they asked for is closed to them.
export const SCREEN_ENTRY_PATHS = {
  conversations: 'dashboard',
  inbox: 'inbox-view',
  calls: 'calls',
  contacts: 'contacts',
  companies: 'companies',
  crm: 'crm/deals',
  help_center: 'portals',
};

// The first part of the path after /accounts/:id/ tells which screen a route belongs to.
const SEGMENT_SCREENS = {
  dashboard: 'conversations',
  conversations: 'conversations',
  inbox: 'conversations',
  label: 'conversations',
  team: 'conversations',
  custom_view: 'conversations',
  mentions: 'conversations',
  unattended: 'conversations',
  participating: 'conversations',
  'inbox-view': 'inbox',
  calls: 'calls',
  contacts: 'contacts',
  companies: 'companies',
  crm: 'crm',
  portals: 'help_center',
};

export const screenForPath = (path = '') => {
  const match = path.match(/\/accounts\/[^/]+\/([^/?#]+)/);
  return match ? SEGMENT_SCREENS[match[1]] || null : null;
};

// `allowedScreens` is null when the person can open everything their role allows.
export const isScreenAllowed = (screen, allowedScreens) =>
  !screen || !Array.isArray(allowedScreens) || allowedScreens.includes(screen);

export const canOpenPath = (path, { allowedScreens, isAdministrator }) =>
  isAdministrator || isScreenAllowed(screenForPath(path), allowedScreens);

const ENTRY_ORDER = [
  'conversations',
  'inbox',
  'calls',
  'contacts',
  'companies',
  'crm',
  'help_center',
];

// First place a restricted person can go; the profile page is open to everyone.
export const firstAllowedPath = (accountId, allowedScreens = []) => {
  const screen = ENTRY_ORDER.find(item => allowedScreens.includes(item));
  const entry = screen ? SCREEN_ENTRY_PATHS[screen] : 'profile/settings';
  return `accounts/${accountId}/${entry}`;
};
