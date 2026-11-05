import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import {
  canResolveConversations,
  getHiddenFields,
} from 'dashboard/helper/permissionsHelper';
import { customFieldKey, isFieldHidden } from 'dashboard/helper/fieldAccess';

// What an administrator switched off for the signed in person: fields they do not see and resolving conversations.
export function useFieldAccess() {
  const user = useMapGetter('getCurrentUser');
  const { accountId } = useAccount();

  const hiddenFields = computed(() =>
    getHiddenFields(user.value, accountId.value)
  );
  const canViewField = field => !isFieldHidden(field, hiddenFields.value);
  const canViewCustomField = (record, key) =>
    canViewField(customFieldKey(record, key));
  const canResolve = computed(() =>
    canResolveConversations(user.value, accountId.value)
  );

  return { hiddenFields, canViewField, canViewCustomField, canResolve };
}
