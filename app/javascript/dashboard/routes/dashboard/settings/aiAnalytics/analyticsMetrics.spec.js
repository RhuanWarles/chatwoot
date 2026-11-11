import {
  averagePerDay,
  daysInMonth,
  isCurrentMonth,
  monthlyAverages,
  outcomeOf,
  peakOf,
  percentChange,
  percentOf,
  periodDays,
  ratio,
  sumOf,
  tokensPerTurn,
} from './analyticsMetrics';

const days = [
  { date: '2026-11-01', messages: 4, conversations: 2 },
  { date: '2026-11-02', messages: 0, conversations: 0 },
  { date: '2026-11-03', messages: 9, conversations: 5 },
  { date: '2026-11-04', messages: 9, conversations: 1 },
];

describe('sums and averages', () => {
  it('sums a series and counts the days of the period', () => {
    expect(sumOf(days, 'messages')).toBe(22);
    expect(sumOf(null, 'messages')).toBe(0);
    expect(periodDays(days)).toBe(4);
  });

  it('averages per day and has no average for an empty period', () => {
    expect(averagePerDay(22, 4)).toBe(5.5);
    expect(averagePerDay(0, 4)).toBeNull();
    expect(averagePerDay(10, 0)).toBeNull();
  });

  it('computes shares and ratios, null without a denominator', () => {
    expect(percentOf(1, 28)).toBeCloseTo(3.571, 2);
    expect(percentOf(0, 10)).toBe(0);
    expect(percentOf(0, 0)).toBeNull();
    expect(ratio(10, 4)).toBe(2.5);
    expect(ratio(10, 0)).toBeNull();
    expect(ratio(0, 4)).toBe(0);
    expect(ratio(null, 4)).toBeNull();
    expect(ratio(undefined, 4)).toBeNull();
  });
});

describe('peakOf', () => {
  it('finds the busiest day, the first one when tied', () => {
    expect(peakOf(days, 'messages')).toEqual({
      index: 2,
      date: '2026-11-03',
      value: 9,
    });
  });

  it('has no peak when nothing happened', () => {
    expect(
      peakOf([{ date: '2026-11-01', messages: 0 }], 'messages')
    ).toBeNull();
    expect(peakOf([], 'messages')).toBeNull();
  });
});

describe('percentChange', () => {
  it('compares with the previous value', () => {
    expect(percentChange(18, 10)).toBe(80);
    expect(percentChange(5, 10)).toBe(-50);
  });

  it('has no change without a usable previous value', () => {
    expect(percentChange(5, 0)).toBeNull();
    expect(percentChange(5, null)).toBeNull();
    expect(percentChange(null, 5)).toBeNull();
  });
});

describe('monthlyAverages', () => {
  const months = [
    { month: '2026-09', ai_replies: 100, human_replies: 50 },
    { month: '2026-10', ai_replies: 200, human_replies: 110 },
    { month: '2026-11', ai_replies: 150, human_replies: 48 },
  ];

  it('averages the current month by the days elapsed and the previous one by all its days', () => {
    const result = monthlyAverages(months, new Date(2026, 10, 11));

    expect(result.current).toBe(18);
    expect(result.previous).toBe(10);
    expect(result.change).toBe(80);
  });

  it('counts the 30 days of November, not 31, for a previous month in December', () => {
    const result = monthlyAverages(
      [
        { month: '2026-11', ai_replies: 300, human_replies: 0 },
        { month: '2026-12', ai_replies: 10, human_replies: 0 },
      ],
      new Date(2026, 11, 10)
    );

    expect(result.previous).toBe(10);
    expect(result.current).toBe(1);
  });

  it('has no average for a month without replies, and so no change', () => {
    const result = monthlyAverages(
      [{ month: '2026-10', ai_replies: 31, human_replies: 0 }],
      new Date(2026, 10, 11)
    );

    expect(result.current).toBeNull();
    expect(result.previous).toBe(1);
    expect(result.change).toBeNull();
  });

  it('knows the length of a month and which one is the current', () => {
    expect(daysInMonth('2026-02')).toBe(28);
    expect(daysInMonth('2028-02')).toBe(29);
    expect(isCurrentMonth('2026-11', new Date(2026, 10, 11))).toBe(true);
    expect(isCurrentMonth('2026-10', new Date(2026, 10, 11))).toBe(false);
  });
});

describe('outcomeOf', () => {
  it('splits the conversations into kept by the AI and handed off', () => {
    const outcome = outcomeOf({ conversations: 28, handoffs: 1 });

    expect(outcome.kept).toBe(27);
    expect(outcome.keptShare).toBeCloseTo(96.43, 2);
    expect(outcome.handoffShare).toBeCloseTo(3.57, 2);
  });

  it('has no shares without conversations', () => {
    expect(outcomeOf({ conversations: 0, handoffs: 0 })).toMatchObject({
      keptShare: null,
      handoffShare: null,
    });
    expect(outcomeOf()).toMatchObject({ conversations: 0, kept: 0 });
  });

  it('never counts more handoffs than conversations', () => {
    expect(outcomeOf({ conversations: 2, handoffs: 5 }).handoffs).toBe(2);
  });
});

describe('tokensPerTurn', () => {
  it('averages the tokens sent and written by each turn', () => {
    expect(
      tokensPerTurn({ prompt_tokens: 9000, completion_tokens: 300 }, 3)
    ).toEqual({ input: 3000, output: 100 });
  });

  it('has no average without turns', () => {
    expect(tokensPerTurn({ prompt_tokens: 9000 }, 0)).toEqual({
      input: null,
      output: null,
    });
  });
});
