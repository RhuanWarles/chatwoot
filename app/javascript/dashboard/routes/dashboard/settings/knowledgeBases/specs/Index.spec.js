import { flushPromises, shallowMount } from '@vue/test-utils';
import Index from '../Index.vue';
import api from 'dashboard/api/knowledgeBases';

const push = vi.fn();

vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: { value: 'pt_BR' } }),
}));
vi.mock('dashboard/api/knowledgeBases', () => ({
  default: { get: vi.fn(), update: vi.fn(), delete: vi.fn() },
}));
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: {
    props: ['label', 'disabled'],
    emits: ['click'],
    template:
      '<button :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
  },
}));
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: {
    template: '<div><slot /></div>',
    methods: { open() {}, close() {} },
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

describe('Knowledge base management', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    api.get.mockResolvedValue({
      data: {
        bases: [
          {
            id: 1,
            name: 'FAQ',
            description: 'Answers',
            active: true,
            agents: [{ name: 'Larissa' }],
            documents_count: 1,
          },
          {
            id: 2,
            name: 'Internal',
            description: 'Team only',
            active: false,
            agents: [],
            documents_count: 0,
          },
        ],
      },
    });
    api.update.mockResolvedValue({
      data: {
        id: 1,
        name: 'FAQ',
        active: false,
        agents: [],
        documents_count: 1,
      },
    });
  });

  it('loads bases, filters them and opens the editor', async () => {
    const wrapper = shallowMount(Index);
    await flushPromises();
    expect(wrapper.text()).toContain('FAQ');
    expect(wrapper.text()).toContain('Internal');
    wrapper.vm.search = 'internal';
    await wrapper.vm.$nextTick();
    expect(wrapper.text()).toContain('Internal');
    expect(wrapper.text()).not.toContain('FAQ');
    wrapper.vm.openEditor({ id: 2 });
    expect(push).toHaveBeenCalledWith({
      name: 'knowledge_base_edit',
      params: { knowledgeBaseId: 2 },
    });
    wrapper.unmount();
  });

  it('toggles and deletes a base through the existing API', async () => {
    const wrapper = shallowMount(Index);
    await flushPromises();
    await wrapper.vm.toggle(wrapper.vm.bases[0]);
    expect(api.update).toHaveBeenCalledWith(1, {
      knowledge_base: { active: false },
    });
    wrapper.vm.target = wrapper.vm.bases[0];
    await wrapper.vm.remove();
    expect(api.delete).toHaveBeenCalledWith(1);
    wrapper.unmount();
  });

  it('shows a recoverable error when the list cannot be loaded', async () => {
    api.get.mockRejectedValue(new Error('unavailable'));
    const wrapper = shallowMount(Index);
    await flushPromises();
    expect(wrapper.find('[role="alert"]').text()).toBe('KNOWLEDGE.ERROR');
    wrapper.unmount();
  });
});
