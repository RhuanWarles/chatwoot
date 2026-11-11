import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router';
import { useEventListener } from '@vueuse/core';

// Asks before leaving with pending edits. Switching items keeps the same route record (only the id
// changes), so the update guard is what protects a click on another item in the list.
// `dialogRef` is a template ref to an UnsavedChangesDialog.
export const useUnsavedChangesGuard = (isDirty, dialogRef) => {
  const confirmLeave = () => (isDirty.value ? dialogRef.value.ask() : true);
  onBeforeRouteLeave(confirmLeave);
  onBeforeRouteUpdate(confirmLeave);
  useEventListener(window, 'beforeunload', event => {
    if (!isDirty.value) return;
    event.preventDefault();
    Object.assign(event, { returnValue: '' });
  });
};
