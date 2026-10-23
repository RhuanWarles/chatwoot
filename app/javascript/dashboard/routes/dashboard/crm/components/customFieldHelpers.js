import { brlFormatter } from './currencyHelpers';

export const isEmptyCustomValue = value =>
  value == null || value === '' || (Array.isArray(value) && !value.length);

// `value` is the typed value (Crm::DealCustomFieldValue#typed_value), never the raw string.
export const formatCustomFieldValue = (fieldType, value, { t, locale }) => {
  const intlLocale = locale.replace('_', '-');
  if (fieldType === 'boolean') return value ? t('CRM.CF_YES') : t('CRM.CF_NO');
  if (fieldType === 'currency') return brlFormatter.format(value);
  if (fieldType === 'date')
    return new Intl.DateTimeFormat(intlLocale).format(
      new Date(value + 'T12:00:00')
    );
  if (fieldType === 'datetime')
    return new Intl.DateTimeFormat(intlLocale, {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(new Date(value));
  return Array.isArray(value) ? value.join(', ') : value;
};
