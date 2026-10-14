import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import Index from '../Index.vue';
import SaasAI from 'dashboard/api/saasAI';

vi.mock('../../components/BaseSettingsHeader.vue', () => ({
  default: { template: '<header />' },
}));
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: { template: '<button />' },
}));
vi.mock('dashboard/components-next/pagination/PaginationFooter.vue', () => ({
  default: {
    name: 'PaginationFooter',
    props: ['currentPage', 'totalItems', 'itemsPerPage'],
    emits: ['update:currentPage'],
    template: '<footer />',
  },
}));

vi.mock('dashboard/api/saasAI', () => ({ default: { get: vi.fn() } }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '48' } }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    currentAccount: ref({ features: { text_ai: true, voice_ai: true } }),
  }),
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
    tm: () => ({ completed: 'Completed' }),
    rt: value => value,
    locale: ref('en'),
  }),
}));

describe('AI usage layout preserves pagination', () => {
  let wrapper;

  beforeEach(() => {
    SaasAI.get.mockResolvedValue({
      data: {
        wallets: [],
        calls: [],
        usage: [
          {
            id: 1,
            resource: 'text_credits',
            kind: 'consumption',
            status: 'completed',
            units: 1,
            created_at: '2026-10-14T00:00:00Z',
          },
        ],
        usage_meta: { total_count: 40, per_page: 20 },
      },
    });
    wrapper = mount(Index, {
      global: {
        stubs: {
          RouterLink: { template: '<a><slot /></a>' },
          WootLoadingState: true,
        },
      },
    });
  });

  afterEach(() => wrapper.unmount());

  it('loads the existing server-side page and keeps pagination outside the records wrapper', async () => {
    await flushPromises();
    expect(SaasAI.get).toHaveBeenCalledWith({ page: 1, per_page: 20 });
    const footer = wrapper.findComponent({ name: 'PaginationFooter' });
    expect(footer.props('totalItems')).toBe(40);
    expect(footer.element.closest('table')).toBeNull();
    expect(
      wrapper.find('table').element.parentElement.contains(footer.element)
    ).toBe(false);
  });

  it('requests the next page without changing page size', async () => {
    await flushPromises();
    wrapper
      .findComponent({ name: 'PaginationFooter' })
      .vm.$emit('update:currentPage', 2);
    await flushPromises();
    expect(SaasAI.get).toHaveBeenLastCalledWith({ page: 2, per_page: 20 });
  });

  it('resets to page one when page size changes', async () => {
    await flushPromises();
    wrapper
      .findComponent({ name: 'PaginationFooter' })
      .vm.$emit('update:currentPage', 2);
    await flushPromises();
    await wrapper.find('select').setValue('50');
    await flushPromises();
    expect(SaasAI.get).toHaveBeenLastCalledWith({ page: 1, per_page: 50 });
  });
});
