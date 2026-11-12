import { ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import TextAgentDetail from '../TextAgentDetail.vue';
import aiAgentsAPI from 'dashboard/api/aiAgents';

const mocks = vi.hoisted(() => ({
  push: vi.fn(),
  alert: vi.fn(),
  guards: {},
  ask: vi.fn(),
  deletionClose: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mocks.push }),
  onBeforeRouteLeave: guard => {
    mocks.guards.leave = guard;
  },
  onBeforeRouteUpdate: guard => {
    mocks.guards.update = guard;
  },
}));
vi.mock('vuex', () => ({
  useStore: () => ({
    getters: { 'inboxes/getInboxes': [{ id: 1, name: 'Support' }] },
  }),
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => mocks.alert(...args),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: { value: '1' } }),
}));
vi.mock('dashboard/api/aiAgents', () => ({
  default: { update: vi.fn(), delete: vi.fn() },
}));

const savedAgent = (extra = {}) => ({
  id: 3,
  name: 'Support assistant',
  description: null,
  provider: 'openai',
  model: 'model',
  system_prompt: 'Help customers',
  timezone: 'Europe/Lisbon',
  temperature: 0.7,
  active: false,
  inboxes: [],
  ...extra,
});

const makeWorkspace = () => ({
  type: ref('text'),
  agents: ref([]),
  textSettings: ref({ mode: 'byok', provider: 'openai', model: 'model' }),
  lookups: ref({ tools: [], knowledgeBases: [], pipelines: [] }),
  ensureLookups: vi.fn().mockResolvedValue(),
  upsert: vi.fn(),
  removeAgent: vi.fn().mockResolvedValue(),
  goToList: vi.fn(),
});

const mountDetail = async (agent = savedAgent()) => {
  const workspace = makeWorkspace();
  const wrapper = shallowMount(TextAgentDetail, {
    props: { agent },
    global: {
      provide: { aiAgentsWorkspace: workspace },
      stubs: {
        UnsavedChangesDialog: {
          template: '<div />',
          methods: { ask: (...args) => mocks.ask(...args) },
        },
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open: vi.fn(), close: () => mocks.deletionClose() },
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

beforeEach(() => {
  vi.clearAllMocks();
  mocks.guards = {};
});

it('organizes the editor into four tabs without losing the draft between tabs', async () => {
  const { wrapper } = await mountDetail();
  const tabs = wrapper.findAll('nav button');

  expect(tabs).toHaveLength(4);
  expect(wrapper.find('section').text()).toContain('AI_AGENTS.TABS.GENERAL');

  await tabs[1].trigger('click');
  expect(wrapper.find('section').text()).toContain('AI_AGENTS.PROMPT_SECTION');
  await tabs[2].trigger('click');
  expect(wrapper.find('section').text()).toContain('AI_AGENTS.AUDIO_ENABLED');
  expect(wrapper.vm.draft.audio_enabled).toBe(false);
  expect(wrapper.find('section').text()).toContain(
    'AI_AGENTS.ATTACHMENT_INTERPRETATION_ENABLED'
  );
  expect(wrapper.vm.draft.attachment_interpretation_enabled).toBe(false);
  await tabs[3].trigger('click');
  expect(wrapper.find('section').text()).toContain(
    'AI_AGENTS.CONNECTIONS_SECTION'
  );
  expect(wrapper.vm.draft.inbox_ids).toEqual([]);
});

it('shows the loaded assistant and waits for the shared lookups once', async () => {
  const { wrapper, workspace } = await mountDetail();

  expect(workspace.ensureLookups).toHaveBeenCalledTimes(1);
  expect(wrapper.vm.draft.name).toBe('Support assistant');
  expect(wrapper.vm.draft.timezone).toBe('Europe/Lisbon');
  expect(wrapper.vm.draft.group_response_blacklist).toEqual([]);
  expect(wrapper.find('header').exists()).toBe(true);
});

it('only enables Save when there are changes, and shows the unsaved state', async () => {
  const { wrapper } = await mountDetail();

  expect(wrapper.text()).not.toContain('AI_AGENTS.UNSAVED');
  expect(
    button(wrapper, 'AI_AGENTS.SAVE').attributes('disabled') === 'true'
  ).toBe(true);
  expect(
    button(wrapper, 'AI_HUB.DISCARD').attributes('disabled') === 'true'
  ).toBe(true);

  wrapper.vm.draft.name = 'Renamed';
  await wrapper.vm.$nextTick();
  expect(wrapper.text()).toContain('AI_AGENTS.UNSAVED');
  expect(
    button(wrapper, 'AI_AGENTS.SAVE').attributes('disabled') === 'true'
  ).toBe(false);
  expect(
    button(wrapper, 'AI_HUB.DISCARD').attributes('disabled') === 'true'
  ).toBe(false);

  wrapper.vm.draft.name = '   ';
  await wrapper.vm.$nextTick();
  expect(
    button(wrapper, 'AI_AGENTS.SAVE').attributes('disabled') === 'true'
  ).toBe(true);
});

it('discards the pending changes and goes back to the saved version', async () => {
  const { wrapper } = await mountDetail();
  wrapper.vm.draft.name = 'Renamed';
  wrapper.vm.draft.system_prompt = 'Other prompt';
  await wrapper.vm.$nextTick();

  button(wrapper, 'AI_HUB.DISCARD').vm.$emit('click');
  await wrapper.vm.$nextTick();

  expect(wrapper.vm.draft.name).toBe('Support assistant');
  expect(wrapper.vm.draft.system_prompt).toBe('Help customers');
  expect(wrapper.vm.isDirty).toBe(false);
});

it('saves with the existing payload, refreshes the list and clears the unsaved state', async () => {
  const agent = savedAgent({
    respond_to_groups: true,
    group_response_blacklist: ['5562999991111'],
  });
  const { wrapper, workspace } = await mountDetail(agent);
  expect(wrapper.vm.draft.group_response_blacklist).toEqual(['5562999991111']);

  wrapper.vm.draft.respond_to_groups = false;
  const saved = { ...agent, respond_to_groups: false };
  aiAgentsAPI.update.mockResolvedValue({ data: saved });
  await wrapper.vm.save();

  expect(aiAgentsAPI.update).toHaveBeenCalledWith(
    3,
    expect.objectContaining({
      ai_agent: expect.objectContaining({
        respond_to_groups: false,
        group_response_blacklist: ['5562999991111'],
      }),
    })
  );
  expect(workspace.upsert).toHaveBeenCalledWith(saved);
  expect(wrapper.vm.isDirty).toBe(false);
  expect(mocks.alert).toHaveBeenCalledWith('AI_AGENTS.SAVED');
  expect(mocks.push).not.toHaveBeenCalled();
});

it('keeps the draft and shows the timezone error when saving fails', async () => {
  const { wrapper, workspace } = await mountDetail();
  wrapper.vm.draft.timezone = 'Nowhere/Land';
  aiAgentsAPI.update.mockRejectedValue({
    response: { data: { field: 'timezone' } },
  });
  await wrapper.vm.save();

  expect(wrapper.vm.timezoneError).toBe('AI_AGENTS.INVALID_TIMEZONE');
  expect(wrapper.vm.draft.timezone).toBe('Nowhere/Land');
  expect(wrapper.vm.isDirty).toBe(true);
  expect(workspace.upsert).not.toHaveBeenCalled();
});

it('toggles active right away without marking the form as changed, and reverts on error', async () => {
  const { wrapper, workspace } = await mountDetail();
  aiAgentsAPI.update.mockResolvedValueOnce({
    data: savedAgent({ active: true }),
  });

  await wrapper.vm.toggleActive();
  expect(aiAgentsAPI.update).toHaveBeenCalledWith(3, {
    ai_agent: { active: true },
  });
  expect(wrapper.vm.draft.active).toBe(true);
  expect(workspace.upsert).toHaveBeenCalled();
  expect(wrapper.vm.isDirty).toBe(false);

  aiAgentsAPI.update.mockRejectedValueOnce({
    response: { data: { error: 'inbox_conflict' } },
  });
  await wrapper.vm.toggleActive();
  expect(wrapper.vm.draft.active).toBe(true);
  expect(mocks.alert).toHaveBeenCalledWith('AI_AGENTS.INBOX_CONFLICT');
});

it('deletes through the API, then opens the next assistant without asking about unsaved changes', async () => {
  const { wrapper, workspace } = await mountDetail();
  wrapper.vm.draft.name = 'Edited and then deleted';
  aiAgentsAPI.delete.mockResolvedValue({});

  await wrapper.vm.remove();

  expect(aiAgentsAPI.delete).toHaveBeenCalledWith(3);
  expect(workspace.removeAgent).toHaveBeenCalledWith(3);
  expect(wrapper.vm.isDirty).toBe(false);
  expect(await mocks.guards.leave()).toBe(true);
  expect(mocks.ask).not.toHaveBeenCalled();
});

it('keeps the assistant and shows an error when deleting fails', async () => {
  const { wrapper, workspace } = await mountDetail();
  aiAgentsAPI.delete.mockRejectedValue(new Error('network'));

  await wrapper.vm.remove();

  expect(workspace.removeAgent).not.toHaveBeenCalled();
  expect(wrapper.vm.actionError).toBe('AI_AGENTS.DELETE_ERROR');
});

it('asks before leaving or switching to another assistant with unsaved changes', async () => {
  const { wrapper } = await mountDetail();

  expect(await mocks.guards.leave()).toBe(true);
  expect(await mocks.guards.update()).toBe(true);
  expect(mocks.ask).not.toHaveBeenCalled();

  wrapper.vm.draft.name = 'Changed';
  mocks.ask.mockResolvedValueOnce(false);
  expect(await mocks.guards.update()).toBe(false);
  mocks.ask.mockResolvedValueOnce(true);
  expect(await mocks.guards.leave()).toBe(true);
  expect(mocks.ask).toHaveBeenCalledTimes(2);
});

it('opens the playground for the assistant', async () => {
  const { wrapper } = await mountDetail();

  button(wrapper, 'AI_AGENTS.TEST').vm.$emit('click');

  expect(mocks.push).toHaveBeenCalledWith({
    name: 'ai_agent_playground',
    params: { accountId: '1', agentId: 3 },
  });
});

// The child components are stubbed in these specs, so a template that points a prop at a name the script
// does not define only shows up as a Vue warning.
it('renders every tab without reading properties that do not exist', async () => {
  const warnings = [];
  const workspace = makeWorkspace();
  const wrapper = shallowMount(TextAgentDetail, {
    props: { agent: savedAgent() },
    global: {
      config: { warnHandler: message => warnings.push(message) },
      provide: { aiAgentsWorkspace: workspace },
      stubs: {
        UnsavedChangesDialog: { template: '<div />' },
        Dialog: { template: '<div><slot /></div>' },
      },
    },
  });
  await flushPromises();
  const tabs = wrapper.findAll('nav button');
  for (let index = 0; index < tabs.length; index += 1) {
    // eslint-disable-next-line no-await-in-loop
    await tabs[index].trigger('click');
  }

  expect(warnings.filter(message => /not defined/.test(message))).toEqual([]);
});

// agentPayload turns an empty value into null, but the handoff conditions field reads its length.
it('keeps the handoff conditions a string when the saved value is empty', async () => {
  const { wrapper } = await mountDetail(
    savedAgent({ handoff_enabled: true, handoff_conditions: null })
  );
  expect(wrapper.vm.draft.handoff_conditions).toBe('');

  wrapper.vm.draft.handoff_conditions = 'Cliente pede cancelamento';
  wrapper.vm.discard();
  expect(wrapper.vm.draft.handoff_conditions).toBe('');
  expect(wrapper.vm.isDirty).toBe(false);
});
