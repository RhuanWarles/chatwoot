import { ref } from 'vue';
import { useOwnRecordsOnly } from '../useOwnRecordsOnly';
import { useStoreGetters } from 'dashboard/composables/store';

vi.mock('dashboard/composables/store');

const withUser = (role, customRoleId = null) =>
  useStoreGetters.mockReturnValue({
    getCurrentRole: ref(role),
    getCurrentCustomRoleId: ref(customRoleId),
  });

describe('useOwnRecordsOnly', () => {
  it('is true for an agent without a custom role', () => {
    withUser('agent');

    expect(useOwnRecordsOnly().isOwnRecordsOnly.value).toBe(true);
  });

  it('is false for an administrator', () => {
    withUser('administrator');

    expect(useOwnRecordsOnly().isOwnRecordsOnly.value).toBe(false);
  });

  it('is false for an agent that has a custom role', () => {
    withUser('agent', 12);

    expect(useOwnRecordsOnly().isOwnRecordsOnly.value).toBe(false);
  });

  it('is false while the role is not loaded yet', () => {
    withUser(undefined);

    expect(useOwnRecordsOnly().isOwnRecordsOnly.value).toBe(false);
  });
});
