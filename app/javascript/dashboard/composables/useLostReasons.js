import { computed, ref } from 'vue';
import { lostReasonsAPI } from 'dashboard/api/crm';

// Every place that marks a deal as lost shares this flow: when the account has active lost
// reasons the agent must pick one in a dialog, otherwise the deal is marked lost directly.
export function useLostReasons() {
  const reasons = ref([]);
  const loaded = ref(false);
  const pendingRequest = ref(null);

  const activeReasons = computed(() =>
    reasons.value.filter(reason => reason.active)
  );
  const needsReason = computed(() => activeReasons.value.length > 0);
  const isLostDialogOpen = computed(() => pendingRequest.value !== null);

  const loadLostReasons = async () => {
    try {
      reasons.value = (await lostReasonsAPI.get()).data;
    } catch {
      reasons.value = [];
    }
    loaded.value = true;
  };

  const settle = result => {
    const request = pendingRequest.value;
    pendingRequest.value = null;
    request?.(result);
  };

  // Resolves with the fields to send along with `status: 'lost'`: `{}` when no reason is
  // needed, `{ lost_reason_id, lost_note }` once chosen, or `null` when the agent cancels.
  const askLostReason = async () => {
    if (!loaded.value) await loadLostReasons();
    if (!needsReason.value) return {};
    settle(null);
    return new Promise(resolve => {
      pendingRequest.value = resolve;
    });
  };

  const confirmLostReason = ({ lost_reason_id: id, lost_note: note }) =>
    settle({ lost_reason_id: id, lost_note: note });
  const cancelLostReason = () => settle(null);

  const findLostReason = id =>
    reasons.value.find(reason => reason.id === id) || null;

  return {
    reasons,
    activeReasons,
    needsReason,
    isLostDialogOpen,
    loadLostReasons,
    askLostReason,
    confirmLostReason,
    cancelLostReason,
    findLostReason,
  };
}
