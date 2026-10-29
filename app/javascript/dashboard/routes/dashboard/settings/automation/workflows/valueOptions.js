import { STATIC_OPTIONS, optionLabelKey } from './constants';
import { FIELD_KINDS, ID_KINDS, resolveField } from './fields';

/**
 * Closed list of { value, label } for a field (values are strings because conditions compare
 * strings), or null when the value is free text.
 */
export const valueOptionsFor = (field, lookups) => {
  const meta = resolveField(field, lookups.customFields);
  const kind = meta?.kind || FIELD_KINDS.TEXT;
  if (kind === FIELD_KINDS.STATIC && meta.options) {
    return STATIC_OPTIONS[meta.options].map(value => ({
      value,
      label: lookups.t(optionLabelKey(meta.options, value)),
    }));
  }
  if (kind === FIELD_KINDS.OPTIONS) {
    return (meta.choices || []).map(choice => ({
      value: String(choice),
      label: String(choice),
    }));
  }
  if (ID_KINDS.includes(kind)) {
    return lookups.options(kind).map(option => ({
      value: String(option.value),
      label: option.label,
    }));
  }
  return null;
};
