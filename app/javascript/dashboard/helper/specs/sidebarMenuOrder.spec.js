import { moveMenuItem, sortByMenuOrder } from '../sidebarMenuOrder';

const tabs = names => names.map(name => ({ name }));
const names = items => items.map(item => item.name);

describe('sortByMenuOrder', () => {
  it('keeps the default order when nothing was chosen', () => {
    const items = tabs(['Inbox', 'Contacts', 'CRM']);

    expect(sortByMenuOrder(items, undefined)).toBe(items);
    expect(sortByMenuOrder(items, null)).toBe(items);
    expect(sortByMenuOrder(items, [])).toBe(items);
  });

  it('follows the order the person chose', () => {
    const items = tabs(['Inbox', 'Contacts', 'CRM']);

    expect(names(sortByMenuOrder(items, ['CRM', 'Inbox', 'Contacts']))).toEqual(
      ['CRM', 'Inbox', 'Contacts']
    );
  });

  it('puts a tab that is not in the list after the listed ones, in its default order', () => {
    const items = tabs(['Inbox', 'Calls', 'Contacts', 'CRM']);

    expect(names(sortByMenuOrder(items, ['CRM', 'Inbox']))).toEqual([
      'CRM',
      'Inbox',
      'Calls',
      'Contacts',
    ]);
  });

  it('ignores names of tabs that do not exist anymore', () => {
    const items = tabs(['Inbox', 'CRM']);

    expect(names(sortByMenuOrder(items, ['Gone', 'CRM', 'Inbox']))).toEqual([
      'CRM',
      'Inbox',
    ]);
  });

  it('does not change the list it was given', () => {
    const items = tabs(['Inbox', 'CRM']);

    sortByMenuOrder(items, ['CRM', 'Inbox']);

    expect(names(items)).toEqual(['Inbox', 'CRM']);
  });
});

describe('moveMenuItem', () => {
  it('moves a tab up and down', () => {
    const items = tabs(['A', 'B', 'C']);

    expect(names(moveMenuItem(items, 1, -1))).toEqual(['B', 'A', 'C']);
    expect(names(moveMenuItem(items, 1, 1))).toEqual(['A', 'C', 'B']);
  });

  it('stays put at the edges', () => {
    const items = tabs(['A', 'B']);

    expect(moveMenuItem(items, 0, -1)).toBe(items);
    expect(moveMenuItem(items, 1, 1)).toBe(items);
  });

  it('does not change the list it was given', () => {
    const items = tabs(['A', 'B']);

    moveMenuItem(items, 0, 1);

    expect(names(items)).toEqual(['A', 'B']);
  });
});
