import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';

// Persisted in the user's ui_settings under `crm_deal_card`. Listed in the order of the
// customizer checklist, which is also the top-to-bottom layout of CrmDealCard.
export const CARD_FIELDS = [
  { key: 'labels', defaultOn: true },
  { key: 'contact', defaultOn: true },
  { key: 'phone', defaultOn: false },
  { key: 'email', defaultOn: false },
  { key: 'company', defaultOn: false },
  { key: 'value', defaultOn: true },
  { key: 'description', defaultOn: false },
  { key: 'created_at', defaultOn: false },
  { key: 'updated_at', defaultOn: false },
  { key: 'owner', defaultOn: true },
  { key: 'next_activity', defaultOn: true },
];

export const DEFAULT_CARD_FIELDS = CARD_FIELDS.filter(
  field => field.defaultOn
).map(field => field.key);

export const useCrmCardConfig = () => {
  const { uiSettings, updateUISettings } = useUISettings();
  const stored = computed(() => uiSettings.value.crm_deal_card);
  const fields = computed(() => stored.value?.fields ?? DEFAULT_CARD_FIELDS);
  const customFieldIds = computed(() => stored.value?.custom_field_ids ?? []);
  const save = (nextFields, nextCustomFieldIds) =>
    updateUISettings({
      crm_deal_card: {
        fields: nextFields,
        custom_field_ids: nextCustomFieldIds,
      },
    });
  const reset = () => updateUISettings({ crm_deal_card: null });
  return { fields, customFieldIds, save, reset };
};
