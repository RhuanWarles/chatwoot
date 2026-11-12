import { EMPTY, formatNumber } from '../settings/aiAnalytics/analyticsFormat';

// "3 min 12 s", "45 s", "1 h 05 min": a time of response as a person says it. No value is "—", never "0 s".
export const formatSeconds = (value, locale = 'pt-BR') => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return EMPTY;
  }
  const total = Math.round(Number(value));
  if (total < 60) return `${formatNumber(total, locale)} s`;
  const minutes = Math.floor(total / 60);
  if (minutes < 60) {
    const seconds = total % 60;
    return seconds ? `${minutes} min ${seconds} s` : `${minutes} min`;
  }
  const hours = Math.floor(minutes / 60);
  return `${hours} h ${String(minutes % 60).padStart(2, '0')} min`;
};

// How long a customer has been waiting, from minutes: "42 min", "1 h 12 min".
export const formatWaiting = minutes => {
  if (minutes === null || minutes === undefined) return EMPTY;
  if (minutes < 60) return `${minutes} min`;
  return `${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, '0')} min`;
};

// A customer waiting this long (minutes) is a customer being left without an answer.
export const WAITING_ATTENTION_MINUTES = 30;
export const isLongWait = minutes =>
  Number(minutes) >= WAITING_ATTENTION_MINUTES;

// 0 to 1, how strong a cell of the heat map is compared with the busiest one.
export const heatLevel = (value, highest) =>
  highest > 0 ? Math.min(1, Number(value || 0) / highest) : 0;

export const heatmapMax = heatmap =>
  Math.max(0, ...(heatmap || []).flatMap(row => row));

// The channel of a campaign, from the type of its inbox ("Channel::Whatsapp" -> "whatsapp").
export const channelKey = type => {
  const name = String(type || '')
    .replace(/^Channel::/, '')
    .toLowerCase();
  if (name === 'webwidget') return 'live_chat';
  return ['whatsapp', 'sms'].includes(name) ? name : 'other';
};
