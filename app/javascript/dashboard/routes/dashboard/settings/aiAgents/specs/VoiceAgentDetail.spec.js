import { ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import VoiceAgentDetail from '../VoiceAgentDetail.vue';
import voiceAgentsAPI from 'dashboard/api/voiceAgents';

const mocks = vi.hoisted(() => ({
  alert: vi.fn(),
  guards: {},
  ask: vi.fn(),
}));

vi.mock('vue-router', () => ({
  onBeforeRouteLeave: guard => {
    mocks.guards.leave = guard;
  },
  onBeforeRouteUpdate: guard => {
    mocks.guards.update = guard;
  },
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => mocks.alert(...args),
}));
vi.mock('dashboard/api/voiceAgents', () => ({
  default: { update: vi.fn(), delete: vi.fn() },
}));

const voiceAgent = (extra = {}) => ({
  id: 4,
  name: 'Fernanda',
  description: null,
  provider: 'vapi',
  assistant_id: null,
  phone_number_id: null,
  active: false,
  inbound_enabled: false,
  outbound_enabled: false,
  max_call_duration: null,
  ...extra,
});

const mountDetail = () => {
  const workspace = {
    voiceMeta: ref({ providers: ['vapi'], durationRange: [10, 3600] }),
    upsert: vi.fn(),
    removeAgent: vi.fn().mockResolvedValue(),
    goToList: vi.fn(),
  };
  const wrapper = shallowMount(VoiceAgentDetail, {
    props: { agent: voiceAgent() },
    global: {
      provide: { aiAgentsWorkspace: workspace },
      stubs: {
        UnsavedChangesDialog: {
          template: '<div />',
          methods: { ask: (...args) => mocks.ask(...args) },
        },
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open: vi.fn(), close: vi.fn() },
        },
      },
    },
  });
  return { wrapper, workspace };
};

beforeEach(() => {
  vi.clearAllMocks();
  mocks.guards = {};
});

it('saves only voice configuration, refreshes the list and clears the unsaved state', async () => {
  const { wrapper, workspace } = mountDetail();
  expect(wrapper.vm.isDirty).toBe(false);

  wrapper.vm.draft.name = 'Fernanda Souza';
  wrapper.vm.draft.assistant_id = 'asst_1';
  expect(wrapper.vm.isDirty).toBe(true);
  const saved = voiceAgent({ name: 'Fernanda Souza', assistant_id: 'asst_1' });
  voiceAgentsAPI.update.mockResolvedValue({ data: saved });
  await wrapper.vm.save();

  expect(voiceAgentsAPI.update).toHaveBeenCalledWith(4, {
    voice_agent: {
      name: 'Fernanda Souza',
      description: '',
      provider: 'vapi',
      assistant_id: 'asst_1',
      phone_number_id: '',
      active: false,
      inbound_enabled: false,
      outbound_enabled: false,
      max_call_duration: null,
    },
  });
  expect(workspace.upsert).toHaveBeenCalledWith(saved);
  expect(wrapper.vm.isDirty).toBe(false);
  expect(mocks.alert).toHaveBeenCalledWith('AI_AGENTS.SAVED');
});

it('keeps the draft for another attempt when saving fails', async () => {
  const { wrapper } = mountDetail();
  wrapper.vm.draft.name = 'Fernanda Souza';
  voiceAgentsAPI.update.mockRejectedValue(new Error('network'));

  await wrapper.vm.save();
  await flushPromises();

  expect(wrapper.text()).toContain('AI_AGENTS.SAVE_ERROR');
  expect(wrapper.vm.draft.name).toBe('Fernanda Souza');
  expect(wrapper.vm.isDirty).toBe(true);
});

it('toggles active right away and restores it when the request fails', async () => {
  const { wrapper } = mountDetail();
  voiceAgentsAPI.update.mockResolvedValueOnce({
    data: voiceAgent({ active: true }),
  });
  await wrapper.vm.toggleActive();
  expect(voiceAgentsAPI.update).toHaveBeenCalledWith(4, {
    voice_agent: { active: true },
  });
  expect(wrapper.vm.draft.active).toBe(true);
  expect(wrapper.vm.isDirty).toBe(false);

  voiceAgentsAPI.update.mockRejectedValueOnce(new Error('network'));
  await wrapper.vm.toggleActive();
  expect(wrapper.vm.draft.active).toBe(true);
  expect(mocks.alert).toHaveBeenCalledWith('AI_AGENTS.SAVE_ERROR');
});

it('deletes and hands the navigation to the list without asking about unsaved changes', async () => {
  const { wrapper, workspace } = mountDetail();
  wrapper.vm.draft.name = 'Edited';
  voiceAgentsAPI.delete.mockResolvedValue({});

  await wrapper.vm.remove();

  expect(voiceAgentsAPI.delete).toHaveBeenCalledWith(4);
  expect(workspace.removeAgent).toHaveBeenCalledWith(4);
  expect(await mocks.guards.leave()).toBe(true);
  expect(mocks.ask).not.toHaveBeenCalled();
});

it('asks before switching to another assistant with unsaved changes', async () => {
  const { wrapper } = mountDetail();
  expect(await mocks.guards.update()).toBe(true);

  wrapper.vm.draft.name = 'Edited';
  mocks.ask.mockResolvedValueOnce(false);
  expect(await mocks.guards.update()).toBe(false);
  expect(mocks.ask).toHaveBeenCalledTimes(1);
});
