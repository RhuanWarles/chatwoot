import { describe, expect, it } from 'vitest';
import { formatCustomFieldValue } from './customFieldHelpers';

const t = key => key;
const agents = [{ id: 7, name: 'Ana' }];

describe('formatCustomFieldValue for a user field', () => {
  it('shows the name of the person that the id points to', () => {
    expect(
      formatCustomFieldValue('user', 7, { t, locale: 'pt_BR', agents })
    ).toBe('Ana');
  });

  it('says so when the person is not on the team any more', () => {
    expect(
      formatCustomFieldValue('user', 99, { t, locale: 'pt_BR', agents })
    ).toBe('CRM.CF_UNKNOWN_USER');
    expect(formatCustomFieldValue('user', 7, { t, locale: 'pt_BR' })).toBe(
      'CRM.CF_UNKNOWN_USER'
    );
  });

  it('keeps formatting the other types as before', () => {
    expect(
      formatCustomFieldValue('boolean', true, { t, locale: 'pt_BR' })
    ).toBe('CRM.CF_YES');
    expect(
      formatCustomFieldValue('multiselect', ['a', 'b'], { t, locale: 'pt_BR' })
    ).toBe('a, b');
  });
});
