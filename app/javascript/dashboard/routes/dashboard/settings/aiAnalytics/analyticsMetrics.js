// Derived numbers of the AI analytics screen. Every function returns null when there is nothing to say, so the screen
// shows "—" instead of a made-up 0 or 0%.
import { dateOnly } from './analyticsFormat';

export const sumOf = (points, key) =>
  (points || []).reduce((total, point) => total + Number(point[key] || 0), 0);

export const percentOf = (part, total) =>
  Number(total) > 0 ? (Number(part || 0) / Number(total)) * 100 : null;

// A missing numerator is "unknown", not zero: dividing nothing by something must not look like a real 0.
export const ratio = (numerator, denominator) =>
  numerator == null || !(Number(denominator) > 0)
    ? null
    : Number(numerator) / Number(denominator);

// How many days the period covers. The API returns one point per day.
export const periodDays = points => (points || []).length;

// Average of a total over some days. A period with nothing in it has no average.
export const averagePerDay = (total, days) =>
  Number(total) > 0 && Number(days) > 0 ? Number(total) / Number(days) : null;

// The busiest day of a series: { index, date, value }, or null when no day had anything.
export const peakOf = (points, key) => {
  let best = null;
  (points || []).forEach((point, index) => {
    const value = Number(point[key] || 0);
    if (value > 0 && (!best || value > best.value)) {
      best = { index, date: dateOnly(point.date), value };
    }
  });
  return best;
};

// Variation in percent between two numbers; null when the base is missing or zero.
export const percentChange = (current, previous) =>
  current == null || !(Number(previous) > 0)
    ? null
    : ((Number(current) - Number(previous)) / Number(previous)) * 100;

export const monthKey = date =>
  `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;

export const daysInMonth = key => {
  const [year, month] = key.split('-').map(Number);
  return new Date(year, month, 0).getDate();
};

export const previousMonthKey = date =>
  monthKey(new Date(date.getFullYear(), date.getMonth() - 1, 1));

// Replies per day of the current month (so far) against the previous month (all of it). `months` is the monthly report:
// [{ month: 'YYYY-MM', ai_replies, human_replies }]. A month without replies has no average.
export const monthlyAverages = (months, now = new Date()) => {
  const replies = key => {
    const row = (months || []).find(item => item.month === key);
    return row
      ? Number(row.ai_replies || 0) + Number(row.human_replies || 0)
      : 0;
  };
  const currentKey = monthKey(now);
  const previousKey = previousMonthKey(now);
  const current = averagePerDay(replies(currentKey), now.getDate());
  const previous = averagePerDay(
    replies(previousKey),
    daysInMonth(previousKey)
  );
  return { current, previous, change: percentChange(current, previous) };
};

export const isCurrentMonth = (month, now = new Date()) =>
  month === monthKey(now);

// Tokens the model receives and writes in one turn, on average.
export const tokensPerTurn = (billing, turns) => ({
  input: ratio(billing?.prompt_tokens, turns),
  output: ratio(billing?.completion_tokens, turns),
});

export const outcomeOf = (summary = {}) => {
  const conversations = Number(summary.conversations || 0);
  const handoffs = Math.min(Number(summary.handoffs || 0), conversations);
  return {
    conversations,
    handoffs,
    kept: conversations - handoffs,
    keptShare: percentOf(conversations - handoffs, conversations),
    handoffShare: percentOf(handoffs, conversations),
  };
};
