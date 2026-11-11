import { ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import KnowledgeBaseDetail from '../KnowledgeBaseDetail.vue';
import api from 'dashboard/api/knowledgeBases';

const mocks = vi.hoisted(() => ({
  alert: vi.fn(),
  guards: {},
  ask: vi.fn(),
  baseDeletionClose: vi.fn(),
}));

vi.mock('vue-router', () => ({
  onBeforeRouteLeave: guard => {
    mocks.guards.leave = guard;
  },
  onBeforeRouteUpdate: guard => {
    mocks.guards.update = guard;
  },
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key}:${params.count ?? ''}` : key),
    locale: { value: 'pt_BR' },
  }),
}));
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => mocks.alert(...args),
}));
vi.mock('dashboard/api/knowledgeBases', () => ({
  default: {
    documents: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    saveDocument: vi.fn(),
    document: vi.fn(),
    deleteDocument: vi.fn(),
    reindex: vi.fn(),
    search: vi.fn(),
  },
}));

const savedBase = (extra = {}) => ({
  id: 7,
  name: 'Support',
  description: null,
  active: true,
  similarity_threshold: '0.4',
  effective_similarity_threshold: 0.4,
  effective_retrieval_top_k: 6,
  effective_chunk_size: 2000,
  effective_chunk_overlap: 200,
  documents_count: 1,
  agents: [{ id: 1, name: 'Larissa' }],
  ...extra,
});

const documentList = [
  {
    id: 11,
    name: 'Refunds',
    status: 'ready',
    source_type: 'manual',
    chunks_count: 3,
    updated_at: '2026-10-22T12:00:00Z',
  },
];

const mountDetail = async (source = savedBase(), warnHandler = undefined) => {
  const workspace = {
    bases: ref([source]),
    upsert: vi.fn(),
    removeBase: vi.fn().mockResolvedValue(),
    goToList: vi.fn(),
  };
  const wrapper = shallowMount(KnowledgeBaseDetail, {
    props: { base: source },
    global: {
      config: warnHandler ? { warnHandler } : {},
      provide: { knowledgeBasesWorkspace: workspace },
      stubs: {
        UnsavedChangesDialog: {
          template: '<div />',
          methods: { ask: (...args) => mocks.ask(...args) },
        },
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open: vi.fn(), close: () => mocks.baseDeletionClose() },
        },
      },
    },
  });
  await flushPromises();
  return { wrapper, workspace };
};

const button = (wrapper, label) =>
  wrapper
    .findAllComponents({ name: 'Button' })
    .find(candidate => candidate.props('label') === label);
const disabled = component => component.attributes('disabled') === 'true';

beforeEach(() => {
  vi.clearAllMocks();
  mocks.guards = {};
  api.documents.mockResolvedValue({ data: { documents: documentList } });
});

it('loads the base and preserves its document and retrieval settings across tabs', async () => {
  const { wrapper } = await mountDetail();
  expect(wrapper.text()).toContain('Support');
  expect(wrapper.text()).toContain('Refunds');
  expect(wrapper.vm.form.description).toBe('');
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

it('keeps the document count of the left panel in step with the documents listed', async () => {
  const { wrapper, workspace } = await mountDetail(
    savedBase({ documents_count: 5 })
  );
  expect(workspace.upsert).toHaveBeenCalledWith(
    expect.objectContaining({ id: 7, documents_count: 1 })
  );
  wrapper.unmount();
});

it('shows the empty documents message only after they loaded', async () => {
  let resolveDocuments;
  api.documents.mockReturnValue(
    new Promise(resolve => {
      resolveDocuments = resolve;
    })
  );
  const { wrapper } = await mountDetail();
  expect(wrapper.text()).not.toContain('KNOWLEDGE.NO_DOCUMENTS');

  resolveDocuments({ data: { documents: [] } });
  await flushPromises();
  expect(wrapper.text()).toContain('KNOWLEDGE.NO_DOCUMENTS');
  wrapper.unmount();
});

it('distinguishes empty search results from search errors', async () => {
  const { wrapper } = await mountDetail();
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

it('only enables Save when there are changes and a name', async () => {
  const { wrapper } = await mountDetail();
  expect(disabled(button(wrapper, 'KNOWLEDGE.SAVE_CHANGES'))).toBe(true);
  expect(disabled(button(wrapper, 'AI_HUB.DISCARD'))).toBe(true);
  expect(wrapper.text()).not.toContain('KNOWLEDGE.UNSAVED');

  wrapper.vm.form.name = 'Renamed';
  await wrapper.vm.$nextTick();
  expect(wrapper.text()).toContain('KNOWLEDGE.UNSAVED');
  expect(disabled(button(wrapper, 'KNOWLEDGE.SAVE_CHANGES'))).toBe(false);

  wrapper.vm.form.name = '   ';
  await wrapper.vm.$nextTick();
  expect(disabled(button(wrapper, 'KNOWLEDGE.SAVE_CHANGES'))).toBe(true);
  wrapper.unmount();
});

it('saves the current settings through the existing API and refreshes the list', async () => {
  const { wrapper, workspace } = await mountDetail();
  wrapper.vm.form.retrieval_top_k = 8;
  api.update.mockResolvedValue({
    data: savedBase({ retrieval_top_k: 8, effective_retrieval_top_k: 8 }),
  });

  await wrapper.vm.save();

  expect(api.update).toHaveBeenCalledWith(7, {
    knowledge_base: expect.objectContaining({
      name: 'Support',
      description: '',
      active: true,
      similarity_threshold: 0.4,
      retrieval_top_k: 8,
    }),
  });
  expect(workspace.upsert).toHaveBeenLastCalledWith(
    expect.objectContaining({ id: 7, retrieval_top_k: 8 })
  );
  expect(wrapper.vm.isDirty).toBe(false);
  expect(mocks.alert).toHaveBeenCalledWith('KNOWLEDGE.SAVED');
  wrapper.unmount();
});

it('uploads a pending file only after updating the existing base, then lists the new document', async () => {
  const { wrapper } = await mountDetail();
  api.update.mockResolvedValue({ data: savedBase() });
  api.saveDocument.mockResolvedValue({ data: { id: 12 } });
  wrapper.vm.pendingFiles.push(
    new File(['Warranty'], 'policy.txt', { type: 'text/plain' })
  );
  expect(wrapper.vm.isDirty).toBe(true);
  api.documents.mockClear();

  await wrapper.vm.save();

  expect(api.update).toHaveBeenCalledWith(7, {
    knowledge_base: expect.objectContaining({
      description: '',
      similarity_threshold: 0.4,
    }),
  });
  expect(api.saveDocument).toHaveBeenCalledWith(7, expect.any(FormData));
  expect(api.update.mock.invocationCallOrder[0]).toBeLessThan(
    api.saveDocument.mock.invocationCallOrder[0]
  );
  expect(api.documents).toHaveBeenCalledTimes(1);
  expect(wrapper.vm.pendingFiles).toEqual([]);
  expect(wrapper.vm.isDirty).toBe(false);
  wrapper.unmount();
});

it('keeps the files that failed to upload and offers a retry', async () => {
  const { wrapper } = await mountDetail();
  api.update.mockResolvedValue({ data: savedBase() });
  api.saveDocument
    .mockResolvedValueOnce({ data: { id: 12 } })
    .mockRejectedValueOnce(new Error('network'));
  const ok = new File(['a'], 'ok.txt', { type: 'text/plain' });
  const bad = new File(['b'], 'bad.txt', { type: 'text/plain' });
  wrapper.vm.pendingFiles.push(ok, bad);

  await wrapper.vm.save();
  await flushPromises();

  expect(wrapper.vm.error).toBe('KNOWLEDGE.PARTIAL_UPLOAD:');
  expect(wrapper.vm.uploadFailed).toBe(true);
  expect(wrapper.vm.pendingFiles).toEqual([bad]);
  expect(button(wrapper, 'KNOWLEDGE.RETRY_FAILED')).toBeTruthy();
  wrapper.unmount();
});

it('does not send NaN when the similarity threshold is invalid', async () => {
  const { wrapper } = await mountDetail();
  wrapper.vm.form.similarity_threshold = 'invalid';

  await wrapper.vm.save();

  expect(api.update).not.toHaveBeenCalled();
  expect(wrapper.vm.error).toBe('KNOWLEDGE.ERROR');
  wrapper.unmount();
});

it('warns that changing the chunking needs a reindex', async () => {
  const { wrapper } = await mountDetail();
  expect(wrapper.vm.changedChunking).toBe(false);
  wrapper.vm.form.chunk_size = 3000;
  expect(wrapper.vm.changedChunking).toBe(true);
  wrapper.unmount();
});

it('discards the pending changes and the files that were not uploaded', async () => {
  const { wrapper } = await mountDetail();
  wrapper.vm.form.name = 'Renamed';
  wrapper.vm.form.retrieval_top_k = 9;
  wrapper.vm.pendingFiles.push(new File(['a'], 'a.txt'));
  await wrapper.vm.$nextTick();

  button(wrapper, 'AI_HUB.DISCARD').vm.$emit('click');
  await wrapper.vm.$nextTick();

  expect(wrapper.vm.form.name).toBe('Support');
  expect(wrapper.vm.form.retrieval_top_k).toBe(6);
  expect(wrapper.vm.pendingFiles).toEqual([]);
  expect(wrapper.vm.isDirty).toBe(false);
  wrapper.unmount();
});

it('toggles active right away without marking the form as changed, and reverts on error', async () => {
  const { wrapper, workspace } = await mountDetail();
  api.update.mockResolvedValueOnce({ data: savedBase({ active: false }) });

  await wrapper.vm.toggleActive();
  expect(api.update).toHaveBeenCalledWith(7, {
    knowledge_base: { active: false },
  });
  expect(wrapper.vm.form.active).toBe(false);
  expect(workspace.upsert).toHaveBeenLastCalledWith(
    expect.objectContaining({ active: false })
  );
  expect(wrapper.vm.isDirty).toBe(false);

  api.update.mockRejectedValueOnce(new Error('network'));
  await wrapper.vm.toggleActive();
  expect(wrapper.vm.form.active).toBe(false);
  expect(mocks.alert).toHaveBeenCalledWith('KNOWLEDGE.ERROR');
  wrapper.unmount();
});

it('deletes the base and hands the navigation to the list without asking about unsaved changes', async () => {
  const { wrapper, workspace } = await mountDetail();
  wrapper.vm.form.name = 'Edited and then deleted';
  api.delete.mockResolvedValue({});

  await wrapper.vm.removeBase();

  expect(api.delete).toHaveBeenCalledWith(7);
  expect(workspace.removeBase).toHaveBeenCalledWith(7);
  expect(await mocks.guards.leave()).toBe(true);
  expect(mocks.ask).not.toHaveBeenCalled();
  wrapper.unmount();
});

it('keeps the base and shows an error when deleting fails', async () => {
  const { wrapper, workspace } = await mountDetail();
  api.delete.mockRejectedValue(new Error('network'));

  await wrapper.vm.removeBase();

  expect(workspace.removeBase).not.toHaveBeenCalled();
  expect(wrapper.vm.error).toBe('KNOWLEDGE.ERROR');
  wrapper.unmount();
});

it('asks before leaving or switching to another base with unsaved changes', async () => {
  const { wrapper } = await mountDetail();
  expect(await mocks.guards.leave()).toBe(true);
  expect(await mocks.guards.update()).toBe(true);
  expect(mocks.ask).not.toHaveBeenCalled();

  wrapper.vm.form.name = 'Changed';
  mocks.ask.mockResolvedValueOnce(false);
  expect(await mocks.guards.update()).toBe(false);
  mocks.ask.mockResolvedValueOnce(true);
  expect(await mocks.guards.leave()).toBe(true);
  expect(mocks.ask).toHaveBeenCalledTimes(2);
  wrapper.unmount();
});

// The child components are stubbed in these specs, so a template that points a prop at a name the script
// does not define only shows up as a Vue warning.
it('renders every tab without reading properties that do not exist', async () => {
  const warnings = [];
  const { wrapper } = await mountDetail(savedBase(), message =>
    warnings.push(message)
  );
  const tabs = ['search', 'settings', 'advanced', 'documents'];
  for (let index = 0; index < tabs.length; index += 1) {
    wrapper.vm.activeTab = tabs[index];
    // eslint-disable-next-line no-await-in-loop
    await wrapper.vm.$nextTick();
  }

  expect(warnings.filter(message => /not defined/.test(message))).toEqual([]);
  wrapper.unmount();
});
