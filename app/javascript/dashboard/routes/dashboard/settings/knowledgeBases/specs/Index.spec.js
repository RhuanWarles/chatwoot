import { shallowMount, flushPromises } from '@vue/test-utils';
import Index from '../Index.vue';
import api from 'dashboard/api/knowledgeBases';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: { value: 'pt_BR' } }),
}));
vi.mock('dashboard/api/knowledgeBases', () => ({
  default: {
    get: vi.fn(),
    documents: vi.fn(),
    create: vi.fn(),
    saveDocument: vi.fn(),
    search: vi.fn(),
  },
}));
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: {
    props: ['label', 'disabled'],
    template: '<button :disabled="disabled">{{ label }}</button>',
  },
}));
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: {
    template: '<div><slot /></div>',
    methods: { open() {}, close() {} },
  },
}));
vi.mock('dashboard/components-next/input/Input.vue', () => ({
  default: { template: '<input />' },
}));
vi.mock('dashboard/components-next/textarea/TextArea.vue', () => ({
  default: { template: '<textarea />' },
}));

describe('Knowledge base management', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    api.get.mockResolvedValue({
      data: {
        bases: [
          {
            id: 1,
            name: 'FAQ',
            active: true,
            agents: [{ name: 'Larissa' }],
            documents_count: 1,
            updated_at: '2026-10-12T12:00:00Z',
          },
        ],
      },
    });
    api.documents.mockResolvedValue({
      data: {
        documents: [
          { id: 2, name: 'Warranty', status: 'ready', chunks_count: 1 },
        ],
      },
    });
  });

  it('loads bases and linked agents and opens document management without creating backend records', async () => {
    const wrapper = shallowMount(Index, {
      global: { stubs: { Button: false, Dialog: false } },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('FAQ');
    expect(wrapper.text()).toContain('Larissa');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'KNOWLEDGE.DOCUMENTS')
      .trigger('click');
    await flushPromises();
    expect(api.documents).toHaveBeenCalledWith(1);
    expect(wrapper.text()).toContain('Warranty');
    expect(api.create).not.toHaveBeenCalled();
    expect(api.saveDocument).not.toHaveBeenCalled();
    wrapper.unmount();
  });

  it('shows a recoverable error when the list cannot be loaded', async () => {
    api.get.mockRejectedValue({ response: { data: { error: 'unavailable' } } });
    const wrapper = shallowMount(Index);
    await flushPromises();
    expect(wrapper.find('[role="alert"]').text()).toBe('KNOWLEDGE.ERROR');
    wrapper.unmount();
  });
});
