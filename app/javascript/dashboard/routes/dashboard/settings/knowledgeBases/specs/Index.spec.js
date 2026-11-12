import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import Index from '../Index.vue';
import EmptyRoute from '../../aiShared/EmptyRoute';
import api from 'dashboard/api/knowledgeBases';

const mocks = vi.hoisted(() => ({ openCreate: vi.fn() }));

vi.mock('dashboard/composables/useAccount', async () => {
  const { computed } = await import('vue');
  const { useRoute } = await import('vue-router');
  return {
    useAccount: () => {
      const route = useRoute();
      return { accountId: computed(() => route.params.accountId) };
    },
  };
});
vi.mock('vue-i18n', async importOriginal => ({
  ...(await importOriginal()),
  useI18n: () => ({
    t: (key, params) => (params ? `${key}:${params.count}` : key),
  }),
}));
vi.mock('dashboard/api/knowledgeBases', () => ({ default: { get: vi.fn() } }));

const base = (id, created, extra = {}) => ({
  id,
  name: `Base ${id}`,
  description: `About ${id}`,
  active: id % 2 === 1,
  agents: [],
  documents_count: id,
  created_at: created,
  ...extra,
});
// The API does not promise the order, the screen sorts newest first.
const list = [
  base(1, '2026-01-01T10:00:00Z'),
  base(3, '2026-03-01T10:00:00Z'),
  base(2, '2026-02-01T10:00:00Z', { name: 'Interno' }),
];

const DetailStub = {
  name: 'DetailStub',
  props: ['knowledgeBaseId'],
  template: '<p data-test="detail">{{ knowledgeBaseId }}</p>',
};
const stubs = {
  Button: {
    props: ['label', 'disabled'],
    emits: ['click'],
    template:
      '<button :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
  },
  Input: {
    props: ['size', 'modelValue', 'placeholder'],
    emits: ['update:modelValue'],
    template:
      '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  },
  KnowledgeBaseCreateDialog: {
    template: '<div />',
    methods: { open: () => mocks.openCreate() },
  },
};

const buildRouter = () =>
  createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/accounts/:accountId/knowledge-bases',
        component: Index,
        children: [
          {
            path: '',
            name: 'knowledge_bases_settings',
            component: EmptyRoute,
          },
          {
            path: ':knowledgeBaseId(\\d+)',
            name: 'knowledge_base_detail',
            component: DetailStub,
            props: true,
          },
        ],
      },
    ],
  });

const mountAt = async path => {
  const router = buildRouter();
  router.push(path);
  await router.isReady();
  const replace = vi.spyOn(router, 'replace');
  const push = vi.spyOn(router, 'push');
  const wrapper = mount(
    { template: '<router-view />' },
    { global: { plugins: [router], stubs } }
  );
  await flushPromises();
  return { router, wrapper, replace, push };
};

const listNames = wrapper =>
  wrapper.findAll('nav a').map(link => link.find('.font-semibold').text());

beforeEach(() => {
  vi.clearAllMocks();
  api.get.mockResolvedValue({ data: { bases: list } });
});

describe('entering the screen', () => {
  it('opens the most recent base with replace and lists them newest first', async () => {
    const { router, wrapper, replace, push } = await mountAt(
      '/accounts/1/knowledge-bases'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases/3'
    );
    expect(replace).toHaveBeenCalledTimes(1);
    expect(push).not.toHaveBeenCalled();
    expect(wrapper.find('[data-test="detail"]').text()).toBe('3');
    expect(listNames(wrapper)).toEqual(['Base 3', 'Interno', 'Base 1']);
  });

  it('shows the document and assistant counts of each base', async () => {
    const { wrapper } = await mountAt('/accounts/1/knowledge-bases');
    expect(wrapper.find('nav a').text()).toContain(
      'KNOWLEDGE.DOCUMENTS_COUNT:3'
    );
    expect(wrapper.find('nav a').text()).toContain('KNOWLEDGE.AGENTS_COUNT:0');
  });

  it('keeps a deep link and highlights the open base', async () => {
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/knowledge-bases/2'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases/2'
    );
    expect(replace).not.toHaveBeenCalled();
    expect(wrapper.find('nav a[aria-current="page"]').text()).toContain(
      'Interno'
    );
  });

  it('replaces an id that does not exist with the most recent base', async () => {
    const { router, replace } = await mountAt('/accounts/1/knowledge-bases/99');

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases/3'
    );
    expect(replace).toHaveBeenCalledTimes(1);
  });
});

describe('empty list', () => {
  beforeEach(() => {
    api.get.mockResolvedValue({ data: { bases: [] } });
  });

  it('shows the empty state with a create button and does not redirect', async () => {
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/knowledge-bases'
    );

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases'
    );
    expect(replace).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('KNOWLEDGE.EMPTY');
    const create = wrapper
      .findAll('button')
      .filter(button => button.text() === 'KNOWLEDGE.CREATE');
    await create[create.length - 1].trigger('click');
    expect(mocks.openCreate).toHaveBeenCalled();
  });

  it('sends an unknown id to the index once and stops there', async () => {
    const { router, replace } = await mountAt('/accounts/1/knowledge-bases/7');

    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases'
    );
    expect(replace).toHaveBeenCalledTimes(1);
  });
});

describe('loading', () => {
  it('shows a skeleton, never the empty state, until the list arrives', async () => {
    let resolveList;
    api.get.mockReturnValue(
      new Promise(resolve => {
        resolveList = resolve;
      })
    );
    const { router, wrapper } = await mountAt('/accounts/1/knowledge-bases');

    expect(wrapper.find('[role="status"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('KNOWLEDGE.EMPTY');
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases'
    );

    resolveList({ data: { bases: list } });
    await flushPromises();
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases/3'
    );
  });

  it('shows a recoverable error and keeps the URL when the list fails', async () => {
    api.get.mockRejectedValueOnce(new Error('unavailable'));
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/knowledge-bases/3'
    );

    expect(wrapper.find('[role="alert"]').text()).toContain('KNOWLEDGE.ERROR');
    expect(replace).not.toHaveBeenCalled();
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases/3'
    );
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'KNOWLEDGE.RETRY')
      .trigger('click');
    await flushPromises();
    expect(wrapper.find('[data-test="detail"]').text()).toBe('3');
  });
});

describe('navigation and filters', () => {
  it('opens another base with push', async () => {
    const { router, wrapper, push } = await mountAt(
      '/accounts/1/knowledge-bases'
    );

    await wrapper.findAll('nav a')[2].trigger('click');
    await flushPromises();

    expect(push).toHaveBeenCalled();
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases/1'
    );
  });

  it('filters the list by search and by status without touching the URL', async () => {
    const { router, wrapper, replace } = await mountAt(
      '/accounts/1/knowledge-bases/3'
    );
    replace.mockClear();

    await wrapper.find('input').setValue('interno');
    expect(listNames(wrapper)).toEqual(['Interno']);

    await wrapper.find('input').setValue('');
    await wrapper.find('select').setValue('active');
    expect(listNames(wrapper)).toEqual(['Base 3', 'Base 1']);

    expect(replace).not.toHaveBeenCalled();
    expect(router.currentRoute.value.fullPath).toBe(
      '/accounts/1/knowledge-bases/3'
    );
  });
});
