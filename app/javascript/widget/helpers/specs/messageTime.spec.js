import {
  formatMessageDateTime,
  formatMessageDay,
  formatMessageTime,
  messageDayKey,
} from '../messageTime';

const unixTime = value => Math.floor(new Date(value).getTime() / 1000);

describe('message time helpers', () => {
  const now = new Date('2026-10-27T14:00:00.000Z');

  it('formats message times in America/Sao_Paulo', () => {
    expect(formatMessageTime(unixTime('2026-10-27T13:31:00.000Z'))).toBe(
      '10:31'
    );
  });

  it('formats the full timestamp for the message tooltip', () => {
    expect(formatMessageDateTime(unixTime('2026-10-27T13:31:00.000Z'))).toMatch(
      /^27\/10\/2026, 10:31$/
    );
  });

  it('labels today, yesterday, and older days in the requested locale', () => {
    expect(
      formatMessageDay(unixTime('2026-10-27T13:31:00.000Z'), { now })
    ).toBe('Hoje');
    expect(
      formatMessageDay(unixTime('2026-10-26T13:31:00.000Z'), { now })
    ).toBe('Ontem');
    expect(
      formatMessageDay(unixTime('2026-10-25T13:31:00.000Z'), { now })
    ).toBe('25 de outubro');
  });

  it('uses calendar days in the configured timezone at a UTC boundary', () => {
    expect(messageDayKey(unixTime('2026-10-27T02:30:00.000Z'))).toBe(
      '2026-10-26'
    );
    expect(messageDayKey(unixTime('2026-10-27T03:30:00.000Z'))).toBe(
      '2026-10-27'
    );
  });

  it('handles historical daylight-saving offsets through Intl', () => {
    expect(formatMessageTime(unixTime('2018-11-04T03:30:00.000Z'))).toBe(
      '01:30'
    );
  });
});
