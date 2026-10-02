import { parsePhoneNumberFromString } from 'libphonenumber-js';
import { formatPhoneNumber } from 'dashboard/components-next/taginput/helper/tagInputHelper';

export const formatContactPhone = value => {
  if (!value) return '';
  const phone = parsePhoneNumberFromString(value);
  if (phone?.country === 'BR') {
    return `+${phone.countryCallingCode} ${phone.formatNational().replace(/[()]/g, '')}`;
  }
  return formatPhoneNumber(value).formattedValue;
};
