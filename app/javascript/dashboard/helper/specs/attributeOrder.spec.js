import {
  mergeAttributeOrder,
  reorderSubset,
  sortByAttributeOrder,
} from '../attributeOrder';

describe('mergeAttributeOrder', () => {
  it('keeps the new order when nothing is hidden', () => {
    expect(mergeAttributeOrder(['a', 'b'], ['b', 'a'])).toEqual(['b', 'a']);
  });

  it('puts a hidden static element back before the element that followed it', () => {
    const saved = ['a', 'static-info', 'b', 'c'];

    expect(mergeAttributeOrder(saved, ['c', 'b', 'a'])).toEqual([
      'c',
      'static-info',
      'b',
      'a',
    ]);
  });

  it('puts a hidden static element at the end when nothing visible followed it', () => {
    expect(mergeAttributeOrder(['a', 'static-info'], ['a'])).toEqual([
      'a',
      'static-info',
    ]);
  });

  it('does not touch static elements that are visible', () => {
    expect(
      mergeAttributeOrder(['static-info', 'a'], ['a', 'static-info'])
    ).toEqual(['a', 'static-info']);
  });

  it('works without a saved order', () => {
    expect(mergeAttributeOrder(undefined, ['a', 'b'])).toEqual(['a', 'b']);
  });
});

describe('sortByAttributeOrder', () => {
  const items = [{ key: 'a' }, { key: 'b' }, { key: 'c' }];
  const keyOf = item => item.key;

  it('follows the saved order and sends unknown elements to the end', () => {
    expect(sortByAttributeOrder(items, keyOf, ['c', 'a']).map(keyOf)).toEqual([
      'c',
      'a',
      'b',
    ]);
  });

  it('returns the elements as they are without a saved order', () => {
    expect(sortByAttributeOrder(items, keyOf, [])).toBe(items);
    expect(sortByAttributeOrder(items, keyOf, undefined)).toBe(items);
  });

  it('does not change the original list', () => {
    sortByAttributeOrder(items, keyOf, ['c']);

    expect(items.map(keyOf)).toEqual(['a', 'b', 'c']);
  });
});

describe('reorderSubset', () => {
  it('moves the elements of the list inside the places they already had', () => {
    expect(reorderSubset(['a', 'x', 'b', 'y', 'c'], ['c', 'a', 'b'])).toEqual([
      'c',
      'x',
      'a',
      'y',
      'b',
    ]);
  });

  it('leaves everything as it was when the list did not change', () => {
    expect(reorderSubset(['a', 'x', 'b'], ['a', 'b'])).toEqual(['a', 'x', 'b']);
  });
});
