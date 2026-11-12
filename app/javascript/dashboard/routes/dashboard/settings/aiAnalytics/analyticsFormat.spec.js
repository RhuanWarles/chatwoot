import {
  EMPTY,
  formatBrazilianDate,
  formatCompact,
  formatDate,
  formatDayMonth,
  formatDuration,
  formatMonth,
  formatNumber,
  formatPercent,
  formatTime,
  formatUsd,
} from './analyticsFormat';

describe('formatNumber', () => {
  it('uses the Brazilian thousand and decimal separators', () => {
    expect(formatNumber(835121)).toBe('835.121');
    expect(formatNumber(1234.56, 'pt-BR', 1)).toBe('1.234,6');
  });

  it('keeps a real zero and shows a dash for a missing value', () => {
    expect(formatNumber(0)).toBe('0');
    expect(formatNumber(null)).toBe(EMPTY);
    expect(formatNumber(undefined)).toBe(EMPTY);
    expect(formatNumber('abc')).toBe(EMPTY);
  });
});

describe('formatPercent', () => {
  it('formats with a comma and at most one decimal', () => {
    expect(formatPercent(37.5)).toBe('37,5%');
    expect(formatPercent(100)).toBe('100%');
    expect(formatPercent(33.333)).toBe('33,3%');
  });

  it('never turns "no data" into 0%', () => {
    expect(formatPercent(null)).toBe(EMPTY);
    expect(formatPercent(undefined)).toBe(EMPTY);
    expect(formatPercent(0)).toBe('0%');
  });
});

describe('formatCompact', () => {
  it('abbreviates thousands and millions', () => {
    expect(formatCompact(9200)).toBe('9,2 mil');
    expect(formatCompact(1200000)).toBe('1,2 mi');
    expect(formatCompact(250)).toBe('250');
    expect(formatCompact(null)).toBe(EMPTY);
  });
});

describe('formatUsd', () => {
  it('prefixes US$ and uses two decimals with a comma', () => {
    expect(formatUsd(1.725546)).toBe('US$ 1,73');
    expect(formatUsd(0.0616)).toBe('US$ 0,06');
    expect(formatUsd(1234.5)).toBe('US$ 1.234,50');
    expect(formatUsd(0)).toBe('US$ 0,00');
  });

  it('shows "< US$ 0,01" for a positive amount below one cent', () => {
    expect(formatUsd(0.004)).toBe('< US$ 0,01');
    expect(formatUsd(0.01)).toBe('US$ 0,01');
  });

  it('shows a dash when there is no estimate', () => {
    expect(formatUsd(null)).toBe(EMPTY);
    expect(formatUsd(undefined)).toBe(EMPTY);
  });

  it('keeps the US$ prefix in other languages', () => {
    expect(formatUsd(1.725546, 'en')).toBe('US$ 1.73');
  });
});

describe('dates', () => {
  it('formats the day the account sees, not the browser day', () => {
    expect(formatDate('2026-11-11')).toBe('11/11/2026');
    expect(formatDayMonth('2026-11-01')).toBe('01/11');
    expect(formatDayMonth('2026-11-01T00:00:00-03:00')).toBe('01/11');
  });

  it('always writes day/month/year for the exported files', () => {
    expect(formatBrazilianDate('2026-03-09')).toBe('09/03/2026');
    expect(formatBrazilianDate('2026-03-09T00:00:00-03:00')).toBe('09/03/2026');
  });

  it('abbreviates a month and formats a time of day', () => {
    expect(formatMonth('2026-10')).toBe('out/26');
    expect(formatMonth('2026-10', 'en')).toBe('Oct/26');
    expect(formatTime(new Date(2026, 10, 11, 9, 5))).toBe('09:05');
  });
});

describe('formatDuration', () => {
  it('picks milliseconds, seconds or minutes', () => {
    expect(formatDuration(450)).toBe('450 ms');
    expect(formatDuration(2500)).toBe('2,5 s');
    expect(formatDuration(125000)).toBe('2 min 5 s');
    expect(formatDuration(null)).toBe(EMPTY);
  });
});
