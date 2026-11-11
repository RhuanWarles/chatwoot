import { flushPromises, shallowMount } from '@vue/test-utils';
import KnowledgeBaseCreateDialog from '../KnowledgeBaseCreateDialog.vue';
import api from 'dashboard/api/knowledgeBases';

const mocks = vi.hoisted(() => ({ open: vi.fn(), close: vi.fn() }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/knowledgeBases', () => ({
  default: { create: vi.fn() },
}));

const mountDialog = () =>
  shallowMount(KnowledgeBaseCreateDialog, {
    global: {
      renderStubDefaultSlot: true,
      stubs: {
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open: mocks.open, close: mocks.close },
        },
      },
    },
  });

beforeEach(() => {
  vi.clearAllMocks();
});

it('only needs a name, like the editor did', () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  expect(mocks.open).toHaveBeenCalled();
  expect(wrapper.vm.canSave).toBe(false);

  wrapper.vm.draft.name = '   ';
  expect(wrapper.vm.canSave).toBe(false);
  wrapper.vm.draft.name = 'FAQ';
  expect(wrapper.vm.canSave).toBe(true);
});

it('creates an active base with the default retrieval settings and reports it', async () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  wrapper.vm.draft.name = 'FAQ';
  wrapper.vm.draft.description = 'Answers';
  const created = { id: 21, name: 'FAQ' };
  api.create.mockResolvedValue({ data: created });

  await wrapper.vm.create();

  expect(api.create).toHaveBeenCalledWith({
    knowledge_base: {
      name: 'FAQ',
      description: 'Answers',
      active: true,
      similarity_threshold: 0.35,
      retrieval_top_k: 5,
      chunk_size: 2400,
      chunk_overlap: 240,
    },
  });
  expect(mocks.close).toHaveBeenCalled();
  expect(wrapper.emitted('created')).toEqual([[created]]);
});

it('stays open and keeps the fields when the request fails', async () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  wrapper.vm.draft.name = 'FAQ';
  api.create.mockRejectedValue(new Error('network'));

  await wrapper.vm.create();
  await flushPromises();

  expect(mocks.close).not.toHaveBeenCalled();
  expect(wrapper.emitted('created')).toBeUndefined();
  expect(wrapper.text()).toContain('KNOWLEDGE.ERROR');
  expect(wrapper.vm.draft.name).toBe('FAQ');
});

it('starts empty every time it is opened', () => {
  const wrapper = mountDialog();
  wrapper.vm.open();
  wrapper.vm.draft.name = 'Leftover';
  wrapper.vm.open();
  expect(wrapper.vm.draft.name).toBe('');
});
