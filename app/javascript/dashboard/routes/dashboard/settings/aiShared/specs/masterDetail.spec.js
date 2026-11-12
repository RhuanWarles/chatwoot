import { computed, defineComponent, ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter, useRoute } from 'vue-router';
import {
  nextAfterRemoval,
  resolveSelection,
  sortNewestFirst,
  useMasterDetailRedirect,
} from '../masterDetail';

const items = [{ id: 7 }, { id: 5 }, { id: 2 }];

describe('sortNewestFirst', () => {
  it('orders by created_at descending and falls back to id', () => {
    const sorted = sortNewestFirst([
      { id: 1, created_at: '2026-01-01T10:00:00Z' },
      { id: 2, created_at: '2026-03-01T10:00:00Z' },
      { id: 3, created_at: '2026-02-01T10:00:00Z' },
      { id: 4, created_at: '2026-03-01T10:00:00Z' },
    ]);
    expect(sorted.map(item => item.id)).toEqual([4, 2, 3, 1]);
    expect(sortNewestFirst([{ id: 1 }, { id: 9 }, { id: 4 }])).toEqual([
      { id: 9 },
      { id: 4 },
      { id: 1 },
    ]);
  });

  it('does not mutate the list it receives', () => {
    const original = [{ id: 1 }, { id: 2 }];
    sortNewestFirst(original);
    expect(original).toEqual([{ id: 1 }, { id: 2 }]);
  });
});

describe('resolveSelection', () => {
  it('opens the newest item from the index', () => {
    expect(
      resolveSelection({ items, selectedId: undefined, atIndex: true })
    ).toEqual({ id: 7 });
  });

  it('keeps a valid id, comparing route strings with numeric ids', () => {
    expect(resolveSelection({ items, selectedId: '5', atIndex: false })).toBe(
      null
    );
  });

  it('replaces an unknown id with the newest item', () => {
    expect(
      resolveSelection({ items, selectedId: '99', atIndex: false })
    ).toEqual({ id: 7 });
  });

  it('goes to the index when the list is empty and an id is requested', () => {
    expect(
      resolveSelection({ items: [], selectedId: '3', atIndex: false })
    ).toEqual({ id: null });
  });

  it('stays on the index for an empty list, so there is no redirect loop', () => {
    expect(
      resolveSelection({ items: [], selectedId: undefined, atIndex: true })
    ).toBe(null);
  });

  it('shows the list first on phones and ignores routes that are not the index', () => {
    expect(
      resolveSelection({
        items,
        selectedId: undefined,
        atIndex: true,
        isMobile: true,
      })
    ).toBe(null);
    expect(
      resolveSelection({ items, selectedId: undefined, atIndex: false })
    ).toBe(null);
  });
});

describe('nextAfterRemoval', () => {
  it('prefers the item below, then the one above, then nothing', () => {
    expect(nextAfterRemoval(items, 7)).toEqual({ id: 5 });
    expect(nextAfterRemoval(items, '5')).toEqual({ id: 2 });
    expect(nextAfterRemoval(items, 2)).toEqual({ id: 5 });
    expect(nextAfterRemoval([{ id: 1 }], 1)).toBe(null);
    expect(nextAfterRemoval(items, 123)).toBe(null);
  });
});

describe('useMasterDetailRedirect', () => {
  const setup = async ({ path, list, loaded = true, isMobile = false }) => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/items', name: 'index', component: { render: () => null } },
        {
          path: '/items/:id(\\d+)',
          name: 'detail',
          component: { render: () => null },
        },
      ],
    });
    const navigations = vi.fn();
    router.afterEach(navigations);
    router.push(path);
    await router.isReady();
    navigations.mockClear();
    const replace = vi.spyOn(router, 'replace');
    const push = vi.spyOn(router, 'push');

    const state = {
      items: ref(list),
      loaded: ref(loaded),
      paused: ref(false),
      isMobile: ref(isMobile),
    };
    mount(
      defineComponent({
        setup() {
          const route = useRoute();
          useMasterDetailRedirect({
            ...state,
            selectedId: computed(() => route.params.id),
            atIndex: computed(() => route.name === 'index'),
            detailLocation: id => ({ name: 'detail', params: { id } }),
            indexLocation: () => ({ name: 'index' }),
          });
          return () => null;
        },
      }),
      { global: { plugins: [router] } }
    );
    await flushPromises();
    return { router, state, navigations, replace, push };
  };

  it('opens the newest item with replace, leaving no extra history entry', async () => {
    const { router, navigations, replace, push } = await setup({
      path: '/items',
      list: items,
    });

    expect(router.currentRoute.value.fullPath).toBe('/items/7');
    expect(navigations).toHaveBeenCalledTimes(1);
    expect(replace).toHaveBeenCalledTimes(1);
    expect(push).not.toHaveBeenCalled();
  });

  it('does not judge the URL before the list has loaded', async () => {
    const { router, state } = await setup({
      path: '/items/99',
      list: [],
      loaded: false,
    });
    expect(router.currentRoute.value.fullPath).toBe('/items/99');

    state.items.value = items;
    state.loaded.value = true;
    await flushPromises();
    expect(router.currentRoute.value.fullPath).toBe('/items/7');
  });

  it('keeps a valid deep link', async () => {
    const { router, navigations } = await setup({
      path: '/items/5',
      list: items,
    });
    expect(router.currentRoute.value.fullPath).toBe('/items/5');
    expect(navigations).not.toHaveBeenCalled();
  });

  it('replaces an id that does not exist with the newest, once', async () => {
    const { router, navigations } = await setup({
      path: '/items/99',
      list: items,
    });
    expect(router.currentRoute.value.fullPath).toBe('/items/7');
    expect(navigations).toHaveBeenCalledTimes(1);
  });

  it('goes to the index for an unknown id on an empty list and stops there', async () => {
    const { router, navigations } = await setup({
      path: '/items/99',
      list: [],
    });
    expect(router.currentRoute.value.fullPath).toBe('/items');
    expect(navigations).toHaveBeenCalledTimes(1);
  });

  it('does nothing on an empty index', async () => {
    const { router, navigations } = await setup({ path: '/items', list: [] });
    expect(router.currentRoute.value.fullPath).toBe('/items');
    expect(navigations).not.toHaveBeenCalled();
  });

  it('stays on the index on phones, but still fixes an unknown id', async () => {
    const onIndex = await setup({
      path: '/items',
      list: items,
      isMobile: true,
    });
    expect(onIndex.router.currentRoute.value.fullPath).toBe('/items');

    const unknown = await setup({
      path: '/items/99',
      list: items,
      isMobile: true,
    });
    expect(unknown.router.currentRoute.value.fullPath).toBe('/items/7');
  });

  it('waits while paused, so a delete can finish its own navigation', async () => {
    const { router, state } = await setup({
      path: '/items/7',
      list: items,
    });
    state.paused.value = true;
    state.items.value = items.slice(1);
    await flushPromises();
    expect(router.currentRoute.value.fullPath).toBe('/items/7');
  });
});
