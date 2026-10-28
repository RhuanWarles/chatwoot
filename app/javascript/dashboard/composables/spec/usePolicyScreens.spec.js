import { ref } from 'vue';
import { usePolicy } from '../usePolicy';

const state = vi.hoisted(() => ({ user: null }));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name =>
    name === 'getCurrentUser'
      ? {
          get value() {
            return state.user;
          },
        }
      : ref(false),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(1) }),
}));
vi.mock('dashboard/composables/useConfig', () => ({
  useConfig: () => ({ isEnterprise: false, enterprisePlanName: '' }),
}));

const signIn = account => {
  state.user = { accounts: [{ id: 1, ...account }] };
};

describe('usePolicy hasScreenAccess', () => {
  it('opens every screen to an agent who was not restricted', () => {
    signIn({ role: 'agent', permissions: ['agent'], allowed_screens: null });
    const { hasScreenAccess } = usePolicy();

    expect(hasScreenAccess('/app/accounts/1/crm/deals')).toBe(true);
    expect(hasScreenAccess('/app/accounts/1/contacts')).toBe(true);
  });

  it('opens only the given screens to a restricted agent', () => {
    signIn({
      role: 'agent',
      permissions: ['agent'],
      allowed_screens: ['contacts'],
    });
    const { hasScreenAccess } = usePolicy();

    expect(hasScreenAccess('/app/accounts/1/contacts/9')).toBe(true);
    expect(hasScreenAccess('/app/accounts/1/crm/deals')).toBe(false);
    expect(hasScreenAccess('/app/accounts/1/dashboard')).toBe(false);
  });

  it('does not restrict pages that are not a screen', () => {
    signIn({
      role: 'agent',
      permissions: ['agent'],
      allowed_screens: ['contacts'],
    });
    const { hasScreenAccess } = usePolicy();

    expect(hasScreenAccess('/app/accounts/1/profile/settings')).toBe(true);
  });

  it('never restricts an administrator', () => {
    signIn({
      role: 'administrator',
      permissions: ['administrator'],
      allowed_screens: ['contacts'],
    });
    const { hasScreenAccess } = usePolicy();

    expect(hasScreenAccess('/app/accounts/1/crm/deals')).toBe(true);
  });
});
