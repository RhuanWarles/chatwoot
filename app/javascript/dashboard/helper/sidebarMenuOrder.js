// The order of the tabs of the sidebar is chosen by each person and kept in their UI settings as a list of tab names.
// A tab that is not in the list (a new one, or one hidden from this person) goes after the listed ones in its default order.
export const sortByMenuOrder = (items, order) => {
  if (!Array.isArray(order) || !order.length) return items;

  const position = name => {
    const index = order.indexOf(name);
    return index === -1 ? Infinity : index;
  };

  return items
    .map((item, index) => ({ item, index }))
    .sort(
      (a, b) =>
        position(a.item.name) - position(b.item.name) || a.index - b.index
    )
    .map(({ item }) => item);
};

// Moves the tab at `index` one place up (-1) or down (+1) without touching the list it was given.
export const moveMenuItem = (items, index, step) => {
  const target = index + step;
  if (target < 0 || target >= items.length) return items;

  const moved = [...items];
  [moved[index], moved[target]] = [moved[target], moved[index]];
  return moved;
};
