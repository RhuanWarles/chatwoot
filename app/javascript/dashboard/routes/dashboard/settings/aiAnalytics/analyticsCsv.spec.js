import {
  CSV_BOM,
  buildActivityCsv,
  csvCell,
  csvFilename,
  downloadCsv,
} from './analyticsCsv';

const labels = {
  date: 'Data',
  conversations: 'Conversas atendidas',
  turns: 'Turnos da IA',
  messages: 'Mensagens enviadas',
  tokens: 'Total de tokens',
  credits: 'Créditos consumidos',
  total: 'Total',
};
const rows = [
  {
    date: '2026-11-02',
    conversations: 3,
    turns: 4,
    messages: 5,
    tokens: 1234567,
    credits: 2,
  },
  {
    date: '2026-11-01',
    conversations: 0,
    turns: 0,
    messages: 0,
    tokens: 0,
    credits: 0,
  },
];
const total = {
  conversations: 3,
  turns: 4,
  messages: 5,
  tokens: 1234567,
  credits: 2,
};

describe('buildActivityCsv', () => {
  const csv = buildActivityCsv({ rows, total, labels });
  const lines = csv.split('\r\n');

  it('starts with the UTF-8 byte order mark so Excel reads the accents', () => {
    expect(csv.startsWith(CSV_BOM)).toBe(true);
    expect(CSV_BOM).toBe('﻿');
  });

  it('separates columns with ";" and starts with the header', () => {
    expect(lines[0]).toBe(
      `${CSV_BOM}Data;Conversas atendidas;Turnos da IA;Mensagens enviadas;Total de tokens`
    );
  });

  it('writes dates as DD/MM/YYYY and numbers without thousand separators', () => {
    expect(lines[1]).toBe('02/11/2026;3;4;5;1234567');
  });

  it('keeps the days without activity as zeros, which Excel can sum', () => {
    expect(lines[2]).toBe('01/11/2026;0;0;0;0');
  });

  it('closes with the total row and a final line break', () => {
    expect(lines[3]).toBe('Total;3;4;5;1234567');
    expect(lines[4]).toBe('');
    expect(lines).toHaveLength(5);
  });

  it('adds the credits column when the account pays in credits', () => {
    const withCredits = buildActivityCsv({
      rows,
      total,
      labels,
      withCredits: true,
    }).split('\r\n');

    expect(withCredits[0]).toContain(';Créditos consumidos');
    expect(withCredits[1]).toBe('02/11/2026;3;4;5;1234567;2');
    expect(withCredits[3]).toBe('Total;3;4;5;1234567;2');
  });

  it('exports only the total row when there are no days', () => {
    const empty = buildActivityCsv({
      rows: [],
      total: { conversations: 0, turns: 0, messages: 0, tokens: 0 },
      labels,
    }).split('\r\n');

    expect(empty).toHaveLength(3);
    expect(empty[1]).toBe('Total;0;0;0;0');
  });
});

describe('csvCell', () => {
  it('quotes a cell that holds the separator, a quote or a line break', () => {
    expect(csvCell('a;b')).toBe('"a;b"');
    expect(csvCell('say "hi"')).toBe('"say ""hi"""');
    expect(csvCell('two\nlines')).toBe('"two\nlines"');
    expect(csvCell('plain')).toBe('plain');
    expect(csvCell(null)).toBe('');
  });
});

describe('csvFilename', () => {
  it('names the file with the local date', () => {
    expect(csvFilename(new Date(2026, 10, 9))).toBe(
      'analytics-ia-2026-11-09.csv'
    );
  });
});

describe('downloadCsv', () => {
  it('hands the file to the browser as a download and cleans up', () => {
    const createObjectURL = vi.fn(() => 'blob:test');
    const revokeObjectURL = vi.fn();
    vi.stubGlobal('URL', { createObjectURL, revokeObjectURL });
    const click = vi
      .spyOn(HTMLAnchorElement.prototype, 'click')
      .mockImplementation(() => {});

    downloadCsv('a;b', 'analytics-ia-2026-11-09.csv');

    const blob = createObjectURL.mock.calls[0][0];
    expect(blob.type).toBe('text/csv;charset=utf-8');
    expect(click).toHaveBeenCalledTimes(1);
    expect(click.mock.instances[0].download).toBe(
      'analytics-ia-2026-11-09.csv'
    );
    expect(revokeObjectURL).toHaveBeenCalledWith('blob:test');
    expect(document.querySelector('a[download]')).toBeNull();

    click.mockRestore();
    vi.unstubAllGlobals();
  });
});
