import { fromUnixTime } from 'date-fns';

export const WIDGET_TIME_ZONE = 'America/Sao_Paulo';

const normalizeLocale = locale => locale?.replace(/_/g, '-') || 'pt-BR';

const parseTimestamp = time => {
  const numericTime = Number(time);
  return Number.isFinite(numericTime) ? fromUnixTime(numericTime) : null;
};

const datePartsInTimeZone = (date, timeZone) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);

  return parts.reduce((dateParts, part) => {
    if (part.type !== 'literal') dateParts[part.type] = Number(part.value);
    return dateParts;
  }, {});
};

const dayNumber = ({ year, month, day }) =>
  Date.UTC(year, month - 1, day) / (24 * 60 * 60 * 1000);

export const messageDayKey = (time, timeZone = WIDGET_TIME_ZONE) => {
  const date = parseTimestamp(time);
  if (!date) return '';

  const { year, month, day } = datePartsInTimeZone(date, timeZone);
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(
    2,
    '0'
  )}`;
};

export const formatMessageDay = (
  time,
  {
    locale = 'pt-BR',
    now = new Date(),
    timeZone = WIDGET_TIME_ZONE,
    todayLabel = 'Hoje',
    yesterdayLabel = 'Ontem',
  } = {}
) => {
  const date = parseTimestamp(time);
  if (!date) return '';

  const messageDateParts = datePartsInTimeZone(date, timeZone);
  const currentDateParts = datePartsInTimeZone(now, timeZone);
  const daysFromNow = dayNumber(currentDateParts) - dayNumber(messageDateParts);

  if (daysFromNow === 0) return todayLabel;
  if (daysFromNow === 1) return yesterdayLabel;

  return new Intl.DateTimeFormat(normalizeLocale(locale), {
    day: 'numeric',
    month: 'long',
    timeZone,
  }).format(date);
};

export const formatMessageTime = (
  time,
  locale = 'pt-BR',
  timeZone = WIDGET_TIME_ZONE
) => {
  const date = parseTimestamp(time);
  if (!date) return '';

  return new Intl.DateTimeFormat(normalizeLocale(locale), {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone,
  }).format(date);
};

export const formatMessageDateTime = (
  time,
  locale = 'pt-BR',
  timeZone = WIDGET_TIME_ZONE
) => {
  const date = parseTimestamp(time);
  if (!date) return '';

  return new Intl.DateTimeFormat(normalizeLocale(locale), {
    dateStyle: 'short',
    timeStyle: 'short',
    timeZone,
  }).format(date);
};

export const messageIsoTime = time => {
  const date = parseTimestamp(time);
  return date ? date.toISOString() : '';
};
