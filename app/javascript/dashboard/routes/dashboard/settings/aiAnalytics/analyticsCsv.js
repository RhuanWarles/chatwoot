import { formatBrazilianDate } from './analyticsFormat';

// Excel in Brazil reads UTF-8 only with a byte order mark, and splits columns on ";".
export const CSV_BOM = '﻿';
export const CSV_SEPARATOR = ';';
const LINE_BREAK = '\r\n';

export const csvCell = value => {
  const text = String(value ?? '');
  return /[";\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

const count = value => String(Math.round(Number(value || 0)));

// The detailed table as a file. `rows` are the days as the table shows them, `total` the closing row.
// `labels`: { date, conversations, turns, messages, tokens, credits, total }; `withCredits` adds the credits column.
export const buildActivityCsv = ({
  rows,
  total,
  labels,
  withCredits = false,
}) => {
  const header = [
    labels.date,
    labels.conversations,
    labels.turns,
    labels.messages,
    labels.tokens,
    ...(withCredits ? [labels.credits] : []),
  ];
  const line = (first, item) => [
    first,
    count(item.conversations),
    count(item.turns),
    count(item.messages),
    count(item.tokens),
    ...(withCredits ? [count(item.credits)] : []),
  ];
  const lines = [
    header,
    ...rows.map(row => line(formatBrazilianDate(row.date), row)),
    line(labels.total, total),
  ];
  return (
    CSV_BOM +
    lines
      .map(cells => cells.map(csvCell).join(CSV_SEPARATOR))
      .join(LINE_BREAK) +
    LINE_BREAK
  );
};

const two = value => String(value).padStart(2, '0');

export const csvFilename = (date = new Date()) =>
  `analytics-ia-${date.getFullYear()}-${two(date.getMonth() + 1)}-${two(date.getDate())}.csv`;

export const downloadCsv = (content, filename) => {
  const blob = new Blob([content], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
};
