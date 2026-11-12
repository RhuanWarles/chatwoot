import { watch } from 'vue';
import { useRouter } from 'vue-router';

const createdAt = item =>
  (item.created_at ? Date.parse(item.created_at) : 0) || 0;

// Newest first. `id` breaks ties and covers payloads without `created_at` (the tools list).
export const sortNewestFirst = items =>
  [...items].sort((a, b) => createdAt(b) - createdAt(a) || b.id - a.id);

const sameId = (item, id) => String(item.id) === String(id);

// Where a master-detail screen has to go once its list is known. `null` keeps the URL as it is,
// `{ id }` replaces it with that item and `{ id: null }` replaces it with the index.
// `items` must already be sorted newest first.
export const resolveSelection = ({ items, selectedId, atIndex, isMobile }) => {
  if (selectedId) {
    if (items.some(item => sameId(item, selectedId))) return null;
    return { id: items[0]?.id ?? null };
  }
  // Phones show the list first; everywhere else the index opens the newest item.
  return atIndex && items.length && !isMobile ? { id: items[0].id } : null;
};

// Item to open once `removedId` is deleted: the one below it in the list, else the one above.
export const nextAfterRemoval = (items, removedId) => {
  const index = items.findIndex(item => sameId(item, removedId));
  if (index === -1) return null;
  return items[index + 1] || items[index - 1] || null;
};

// Applies `resolveSelection` with `router.replace`, never `push`, so the back button cannot loop.
// The URL is only judged after the list loaded, otherwise every deep link would look invalid.
// `paused` lets the screen finish its own navigation (after a delete) without a competing redirect.
export const useMasterDetailRedirect = ({
  items,
  loaded,
  selectedId,
  atIndex,
  isMobile,
  paused,
  detailLocation,
  indexLocation,
}) => {
  const router = useRouter();
  watch(
    [loaded, items, selectedId, atIndex, isMobile],
    () => {
      if (!loaded.value || paused.value) return;
      const target = resolveSelection({
        items: items.value,
        selectedId: selectedId.value,
        atIndex: atIndex.value,
        isMobile: isMobile.value,
      });
      if (!target) return;
      router.replace(target.id ? detailLocation(target.id) : indexLocation());
    },
    { immediate: true }
  );
};
