import { flushPromises, shallowMount } from '@vue/test-utils';
import KnowledgeBaseEditorPage from '../KnowledgeBaseEditorPage.vue';
import api from 'dashboard/api/knowledgeBases';

const push = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { knowledgeBaseId: 7 } }),
  useRouter: () => ({ push }),
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: { value: 'pt_BR' } }),
}));
vi.mock('dashboard/api/knowledgeBases', () => ({
  default: {
    show: vi.fn(),
    documents: vi.fn(),
    update: vi.fn(),
    create: vi.fn(),
    saveDocument: vi.fn(),
    document: vi.fn(),
    deleteDocument: vi.fn(),
    reindex: vi.fn(),
    search: vi.fn(),
  },
}));
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: {
    props: ['label', 'disabled', 'isLoading'],
    emits: ['click'],
    template:
      '<button :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
  },
}));
vi.mock('dashboard/components-next/input/Input.vue', () => ({
  default: {
    props: ['modelValue'],
    emits: ['update:modelValue'],
    template:
      '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  },
}));
vi.mock('dashboard/components-next/textarea/TextArea.vue', () => ({
  default: {
    props: ['modelValue'],
    emits: ['update:modelValue'],
    template:
      '<textarea :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  },
}));
vi.mock('dashboard/components-next/switch/Switch.vue', () => ({
  default: {
    props: ['modelValue'],
    emits: ['update:modelValue'],
    template: '<input type="checkbox" :checked="modelValue" />',
  },
}));
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: {
    template: '<div><slot /></div>',
    methods: { open() {}, close() {} },
  },
}));

describe('Knowledge base editor', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    api.show.mockResolvedValue({
      data: {
        id: 7,
        name: 'Support',
        description: 'Policies',
        active: true,
        effective_similarity_threshold: 0.4,
        effective_retrieval_top_k: 6,
        effective_chunk_size: 2000,
        effective_chunk_overlap: 200,
      },
    });
    api.documents.mockResolvedValue({
      data: {
        documents: [
          {
            id: 11,
            name: 'Refunds',
            status: 'ready',
            source_type: 'manual',
            chunks_count: 3,
            updated_at: '2026-10-22T12:00:00Z',
          },
        ],
      },
    });
  });

  it('loads the base and preserves its document and retrieval settings across tabs', async () => {
    const wrapper = shallowMount(KnowledgeBaseEditorPage);
    await flushPromises();
    expect(wrapper.text()).toContain('Support');
    expect(wrapper.text()).toContain('Refunds');
    expect(wrapper.vm.form.similarity_threshold).toBe(0.4);
    expect(wrapper.vm.form.retrieval_top_k).toBe(6);
    wrapper.vm.activeTab = 'advanced';
    await wrapper.vm.$nextTick();
    expect(wrapper.text()).toContain('KNOWLEDGE.TAB_ADVANCED');
    wrapper.vm.activeTab = 'documents';
    await wrapper.vm.$nextTick();
    expect(wrapper.text()).toContain('Refunds');
    wrapper.unmount();
  });

  it('distinguishes empty search results from search errors', async () => {
    const wrapper = shallowMount(KnowledgeBaseEditorPage);
    await flushPromises();
    wrapper.vm.activeTab = 'search';
    wrapper.vm.query = 'refund';
    api.search.mockResolvedValue({ data: { candidates: [] } });
    await wrapper.vm.testSearch();
    expect(wrapper.vm.candidates).toEqual([]);
    expect(wrapper.vm.searchError).toBe('');
    api.search.mockRejectedValue(new Error('network'));
    await wrapper.vm.testSearch();
    expect(wrapper.vm.candidates).toBeNull();
    expect(wrapper.vm.searchError).toBe('KNOWLEDGE.SEARCH_ERROR');
    wrapper.unmount();
  });

  it('saves current settings through the existing API', async () => {
    const wrapper = shallowMount(KnowledgeBaseEditorPage);
    await flushPromises();
    await wrapper.vm.save();
    expect(api.update).toHaveBeenCalledWith(7, {
      knowledge_base: expect.objectContaining({
        name: 'Support',
        similarity_threshold: 0.4,
        retrieval_top_k: 6,
      }),
    });
    wrapper.unmount();
  });
});
