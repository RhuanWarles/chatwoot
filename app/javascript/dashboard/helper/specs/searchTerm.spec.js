import { normalizeSearchTerm } from '../searchTerm';

describe('normalizeSearchTerm', () => {
  it.each([
    ['(62) 99121-2010', '62991212010'],
    ['62 99121 2010', '62991212010'],
    ['+55 62 99121-2010', '+5562991212010'],
    ['+5562991212010', '+5562991212010'],
    ['  99121-2010  ', '991212010'],
    ['62.99121.2010', '62991212010'],
  ])('turns the phone %s into %s', (typed, expected) => {
    expect(normalizeSearchTerm(typed)).toBe(expected);
  });

  it.each([
    ['Jorge Silva', 'Jorge Silva'],
    ['  jorge  ', 'jorge'],
    ['jorge2010', 'jorge2010'],
    ['maria@example.com', 'maria@example.com'],
  ])('keeps the text %s as it is, only trimmed', (typed, expected) => {
    expect(normalizeSearchTerm(typed)).toBe(expected);
  });

  it('does not strip short numbers, which can be a conversation id', () => {
    expect(normalizeSearchTerm('1-2')).toBe('1-2');
    expect(normalizeSearchTerm('123')).toBe('123');
  });

  it('copes with empty values', () => {
    expect(normalizeSearchTerm('')).toBe('');
    expect(normalizeSearchTerm(undefined)).toBe('');
    expect(normalizeSearchTerm(null)).toBe('');
  });
});
