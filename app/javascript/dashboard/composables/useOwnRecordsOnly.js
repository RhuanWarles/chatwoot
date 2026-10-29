import { computed } from 'vue';
import { useStoreGetters } from 'dashboard/composables/store';

/**
 * True for an agent without a custom role: they only work with the conversations assigned to them
 * and the CRM cards they own. Administrators and custom-role agents are not affected.
 * @returns {{ isOwnRecordsOnly: import('vue').ComputedRef<boolean> }}
 */
export function useOwnRecordsOnly() {
  const getters = useStoreGetters();

  const isOwnRecordsOnly = computed(
    () =>
      getters.getCurrentRole.value === 'agent' &&
      !getters.getCurrentCustomRoleId.value
  );

  return { isOwnRecordsOnly };
}
