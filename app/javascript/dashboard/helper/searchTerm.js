// Phone numbers are stored like +5562991212010, so a number typed the way people write it, "(62) 99121-2010" or
// "+55 62 99121-2010", would never match. Anything that looks like a phone number is reduced to its digits (keeping
// a leading +); anything else, like a name, is only trimmed.
const LOOKS_LIKE_PHONE = /^\+?[\d\s().-]+$/;
const MIN_PHONE_DIGITS = 4;

export const normalizeSearchTerm = term => {
  const trimmed = String(term ?? '').trim();
  if (!LOOKS_LIKE_PHONE.test(trimmed)) return trimmed;

  const digits = trimmed.replace(/\D/g, '');
  if (digits.length < MIN_PHONE_DIGITS) return trimmed;

  return `${trimmed.startsWith('+') ? '+' : ''}${digits}`;
};
