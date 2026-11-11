// Formatting for the AI analytics screen. A value that does not exist is "—", never 0 or 0%: "no data" and "zero" are
// different things and the screen must not blur them.
export const EMPTY = '—';
export const DEFAULT_LOCALE = 'pt-BR';

const isMissing = value =>
  value === null ||
  value === undefined ||
  value === '' ||
  Number.isNaN(Number(value));

export const formatNumber = (value, locale = DEFAULT_LOCALE, digits = 0) =>
  isMissing(value)
    ? EMPTY
    : new Intl.NumberFormat(locale, { maximumFractionDigits: digits }).format(
        Number(value)
      );

export const formatPercent = (value, locale = DEFAULT_LOCALE, digits = 1) =>
  isMissing(value) ? EMPTY : `${formatNumber(value, locale, digits)}%`;

// 1.2 million tokens -> "1,2 mi", 9,200 -> "9,2 mil".
export const formatCompact = (value, locale = DEFAULT_LOCALE) =>
  isMissing(value)
    ? EMPTY
    : new Intl.NumberFormat(locale, {
        notation: 'compact',
        maximumFractionDigits: 1,
      })
        .format(Number(value))
        .replace(/\s+/g, ' ');

// Always "US$" in front, whatever the language: the price list is in dollars and the screen does not convert.
export const formatUsd = (value, locale = DEFAULT_LOCALE) => {
  if (isMissing(value)) return EMPTY;
  const amount = Number(value);
  const money = number =>
    new Intl.NumberFormat(locale, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(number);
  if (amount > 0 && amount < 0.01) return `< US$ ${money(0.01)}`;
  return `US$ ${money(amount)}`;
};

// Dates arrive as "YYYY-MM-DD" (or an ISO timestamp already in the account time zone). Reading only the date part keeps
// the day the account sees, whatever the time zone of the browser.
export const dateOnly = value => String(value || '').slice(0, 10);

const utcDate = value => new Date(`${dateOnly(value)}T00:00:00Z`);

export const formatDate = (value, locale = DEFAULT_LOCALE) =>
  new Intl.DateTimeFormat(locale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(utcDate(value));

export const formatDayMonth = (value, locale = DEFAULT_LOCALE) =>
  new Intl.DateTimeFormat(locale, {
    day: '2-digit',
    month: '2-digit',
    timeZone: 'UTC',
  }).format(utcDate(value));

// "2026-10" -> "out/26"
export const formatMonth = (month, locale = DEFAULT_LOCALE) =>
  new Intl.DateTimeFormat(locale, {
    month: 'short',
    year: '2-digit',
    timeZone: 'UTC',
  }).format(new Date(`${month}-01T00:00:00Z`));

export const formatTime = (date, locale = DEFAULT_LOCALE) =>
  new Intl.DateTimeFormat(locale, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);

export const formatDuration = (milliseconds, locale = DEFAULT_LOCALE) => {
  if (isMissing(milliseconds)) return EMPTY;
  const value = Number(milliseconds);
  if (value < 1000) return `${formatNumber(value, locale)} ms`;
  if (value < 60000) return `${formatNumber(value / 1000, locale, 1)} s`;
  const minutes = Math.floor(value / 60000);
  const seconds = Math.round((value % 60000) / 1000);
  return `${minutes} min ${seconds} s`;
};

// The files the screen exports are read by Excel in Brazil: always day/month/year, whatever the screen language.
export const formatBrazilianDate = value => {
  const [year, month, day] = dateOnly(value).split('-');
  return `${day}/${month}/${year}`;
};
