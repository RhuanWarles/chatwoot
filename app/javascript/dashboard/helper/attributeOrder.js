// Keys of the elements the conversation sidebar shows next to the attributes (contact info, buttons...) start with this.
export const STATIC_KEY_PREFIX = 'static-';

// The sidebar of a conversation and the contact page share one saved order. Some elements are not shown everywhere
// (the static ones, depending on the channel), so a new order never drops them: each one is put back before the
// element that followed it in the saved order.
export const mergeAttributeOrder = (savedOrder = [], currentOrder = []) => {
  const finalOrder = [...currentOrder];
  const visibleKeys = new Set(currentOrder);

  savedOrder
    .filter(key => key.startsWith(STATIC_KEY_PREFIX) && !visibleKeys.has(key))
    .forEach(staticKey => {
      const nextVisible = savedOrder
        .slice(savedOrder.indexOf(staticKey))
        .find(key => visibleKeys.has(key));

      if (nextVisible) {
        finalOrder.splice(finalOrder.indexOf(nextVisible), 0, staticKey);
      } else {
        finalOrder.push(staticKey);
      }
    });

  return finalOrder;
};

// Orders the elements by the saved order; the ones it does not know go last, in their own order.
export const sortByAttributeOrder = (elements, keyOf, savedOrder = []) => {
  if (!savedOrder?.length) return elements;

  const positions = new Map(savedOrder.map((key, index) => [key, index]));
  return [...elements].sort(
    (a, b) =>
      (positions.get(keyOf(a)) ?? Infinity) -
      (positions.get(keyOf(b)) ?? Infinity)
  );
};

// A list that shows only some of the elements was reordered: its elements take the same places in the whole order,
// so the elements that are not in the list stay where they were.
export const reorderSubset = (allKeys, subsetKeysInNewOrder) => {
  const subset = new Set(subsetKeysInNewOrder);
  const queue = [...subsetKeysInNewOrder];
  return allKeys.map(key => (subset.has(key) ? queue.shift() : key));
};
