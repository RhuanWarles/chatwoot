import {
  channelKey,
  formatSeconds,
  formatWaiting,
  heatLevel,
  heatmapMax,
  isLongWait,
} from './dashboardMetrics';

describe('formatSeconds', () => {
  it('says a time of response the way a person does', () => {
    expect(formatSeconds(45)).toBe('45 s');
    expect(formatSeconds(192)).toBe('3 min 12 s');
    expect(formatSeconds(180)).toBe('3 min');
    expect(formatSeconds(3900)).toBe('1 h 05 min');
  });

  it('shows a dash, not 0 s, when there is nothing to say', () => {
    expect(formatSeconds(null)).toBe('—');
    expect(formatSeconds(undefined)).toBe('—');
    expect(formatSeconds('abc')).toBe('—');
  });
});

describe('formatWaiting', () => {
  it('writes minutes, then hours and minutes', () => {
    expect(formatWaiting(42)).toBe('42 min');
    expect(formatWaiting(72)).toBe('1 h 12 min');
    expect(formatWaiting(null)).toBe('—');
  });

  it('flags a wait of half an hour or more', () => {
    expect(isLongWait(29)).toBe(false);
    expect(isLongWait(30)).toBe(true);
    expect(isLongWait(null)).toBe(false);
  });
});

describe('heat map', () => {
  it('scales each cell to the busiest one and copes with an empty map', () => {
    expect(heatLevel(5, 10)).toBe(0.5);
    expect(heatLevel(20, 10)).toBe(1);
    expect(heatLevel(3, 0)).toBe(0);
    expect(
      heatmapMax([
        [1, 7],
        [3, 2],
      ])
    ).toBe(7);
    expect(heatmapMax([])).toBe(0);
    expect(heatmapMax(undefined)).toBe(0);
  });
});

describe('channelKey', () => {
  it('maps the type of the inbox to a channel the screen has a name for', () => {
    expect(channelKey('Channel::Whatsapp')).toBe('whatsapp');
    expect(channelKey('Channel::Sms')).toBe('sms');
    expect(channelKey('Channel::WebWidget')).toBe('live_chat');
    expect(channelKey('Channel::Email')).toBe('other');
    expect(channelKey(null)).toBe('other');
  });
});
