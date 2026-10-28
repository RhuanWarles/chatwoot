import {
  SCREENS,
  SCREEN_ENTRY_PATHS,
  canOpenPath,
  firstAllowedPath,
  isScreenAllowed,
  screenForPath,
} from '../screenAccess';

describe('screenForPath', () => {
  it.each([
    ['/app/accounts/1/dashboard', 'conversations'],
    ['/app/accounts/1/conversations/42', 'conversations'],
    ['/app/accounts/1/inbox/3', 'conversations'],
    ['/app/accounts/1/label/vip', 'conversations'],
    ['/app/accounts/1/team/2', 'conversations'],
    ['/app/accounts/1/mentions/conversations', 'conversations'],
    ['/app/accounts/1/unattended/conversations', 'conversations'],
    ['/app/accounts/1/inbox-view/mentions/5', 'inbox'],
    ['/app/accounts/1/calls', 'calls'],
    ['/app/accounts/1/contacts/30', 'contacts'],
    ['/app/accounts/1/companies', 'companies'],
    ['/app/accounts/1/crm/deals/9', 'crm'],
    ['/app/accounts/1/crm/segments', 'crm'],
    ['/app/accounts/1/portals/main/en/articles', 'help_center'],
  ])('%s belongs to %s', (path, screen) => {
    expect(screenForPath(path)).toBe(screen);
  });

  it.each([
    '/app/accounts/1/settings/agents',
    '/app/accounts/1/profile/settings',
    '/app/accounts/1/reports/overview',
    '/app/login',
    '',
  ])('%s belongs to no screen that can be switched off', path => {
    expect(screenForPath(path)).toBeNull();
  });

  it('does not mistake a path that only starts like another one', () => {
    expect(screenForPath('/app/accounts/1/crmx/deals')).toBeNull();
    expect(screenForPath('/app/accounts/1/inbox-view')).toBe('inbox');
    expect(screenForPath('/app/accounts/1/inbox/3')).toBe('conversations');
  });
});

describe('isScreenAllowed', () => {
  it('allows everything when nothing was restricted', () => {
    expect(isScreenAllowed('crm', null)).toBe(true);
    expect(isScreenAllowed('crm', undefined)).toBe(true);
  });

  it('allows only the chosen screens when restricted', () => {
    expect(isScreenAllowed('crm', ['crm', 'calls'])).toBe(true);
    expect(isScreenAllowed('contacts', ['crm', 'calls'])).toBe(false);
  });

  it('always allows pages that are not a screen', () => {
    expect(isScreenAllowed(null, ['crm'])).toBe(true);
  });
});

describe('canOpenPath', () => {
  const restricted = { allowedScreens: ['contacts'], isAdministrator: false };

  it('lets administrators open everything', () => {
    expect(
      canOpenPath('/app/accounts/1/crm/deals', {
        allowedScreens: ['contacts'],
        isAdministrator: true,
      })
    ).toBe(true);
  });

  it('blocks the screens a restricted agent was not given', () => {
    expect(canOpenPath('/app/accounts/1/crm/deals', restricted)).toBe(false);
    expect(canOpenPath('/app/accounts/1/contacts', restricted)).toBe(true);
  });

  it('never blocks the profile or settings pages', () => {
    expect(canOpenPath('/app/accounts/1/profile/settings', restricted)).toBe(
      true
    );
  });
});

describe('firstAllowedPath', () => {
  it('sends the person to the first screen they can open', () => {
    expect(firstAllowedPath(7, ['crm', 'contacts'])).toBe(
      'accounts/7/contacts'
    );
  });

  it('prefers conversations when allowed', () => {
    expect(firstAllowedPath(7, ['crm', 'conversations'])).toBe(
      'accounts/7/dashboard'
    );
  });

  it('falls back to the help center, then to the profile page', () => {
    expect(firstAllowedPath(7, ['help_center'])).toBe('accounts/7/portals');
    expect(firstAllowedPath(7, [])).toBe('accounts/7/profile/settings');
  });

  it('has an entry page for every screen', () => {
    expect(Object.keys(SCREEN_ENTRY_PATHS).sort()).toEqual([...SCREENS].sort());
  });
});
