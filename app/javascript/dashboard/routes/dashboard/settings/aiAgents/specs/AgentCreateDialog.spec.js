import { ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import AgentCreateDialog from '../AgentCreateDialog.vue';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import voiceAgentsAPI from 'dashboard/api/voiceAgents';

const mocks = vi.hoisted(() => ({ open: vi.fn(), close: vi.fn() }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/aiAgents', () => ({ default: { create: vi.fn() } }));
vi.mock('dashboard/api/voiceAgents', () => ({ default: { create: vi.fn() } }));

const workspace = {
  textSettings: ref({ mode: 'byok', provider: 'openai', model: 'gpt-4.1' }),
  voiceMeta: ref({ providers: ['vapi'], durationRange: [10, 3600] }),
};

const mountDialog = type =>
  shallowMount(AgentCreateDialog, {
    props: { type },
    global: {
      provide: { aiAgentsWorkspace: workspace },
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

describe('text assistant', () => {
  it('only needs a name and instructions, using the configured provider and model', async () => {
    const wrapper = mountDialog('text');
    wrapper.vm.open();
    expect(mocks.open).toHaveBeenCalled();
    expect(wrapper.vm.canSave).toBe(false);

    wrapper.vm.textDraft.name = 'Support';
    expect(wrapper.vm.canSave).toBe(false);
    wrapper.vm.textDraft.system_prompt = 'Help customers';
    expect(wrapper.vm.canSave).toBe(true);

    const created = { id: 9, name: 'Support' };
    aiAgentsAPI.create.mockResolvedValue({ data: created });
    await wrapper.vm.create();

    expect(aiAgentsAPI.create).toHaveBeenCalledWith({
      ai_agent: expect.objectContaining({
        name: 'Support',
        system_prompt: 'Help customers',
        provider: 'openai',
        model: 'gpt-4.1',
        active: false,
      }),
    });
    expect(mocks.close).toHaveBeenCalled();
    expect(wrapper.emitted('created')).toEqual([[created]]);
  });

  it('stays open with an error and creates nothing when the request fails', async () => {
    const wrapper = mountDialog('text');
    wrapper.vm.open();
    wrapper.vm.textDraft.name = 'Support';
    wrapper.vm.textDraft.system_prompt = 'Help customers';
    aiAgentsAPI.create.mockRejectedValue(new Error('network'));

    await wrapper.vm.create();
    await flushPromises();

    expect(mocks.close).not.toHaveBeenCalled();
    expect(wrapper.emitted('created')).toBeUndefined();
    expect(wrapper.text()).toContain('AI_AGENTS.SAVE_ERROR');
    expect(wrapper.vm.textDraft.name).toBe('Support');
  });

  it('starts empty every time it is opened', () => {
    const wrapper = mountDialog('text');
    wrapper.vm.open();
    wrapper.vm.textDraft.name = 'Leftover';
    wrapper.vm.open();
    expect(wrapper.vm.textDraft.name).toBe('');
  });
});

describe('voice assistant', () => {
  it('only needs a name and a provider', async () => {
    const wrapper = mountDialog('voice');
    wrapper.vm.open();
    expect(wrapper.vm.canSave).toBe(false);

    wrapper.vm.voiceDraft.name = 'Fernanda';
    expect(wrapper.vm.canSave).toBe(true);
    const created = { id: 4, name: 'Fernanda', provider: 'vapi' };
    voiceAgentsAPI.create.mockResolvedValue({ data: created });
    await wrapper.vm.create();

    expect(voiceAgentsAPI.create).toHaveBeenCalledWith({
      voice_agent: {
        name: 'Fernanda',
        description: '',
        provider: 'vapi',
        assistant_id: '',
        phone_number_id: '',
        active: false,
        inbound_enabled: false,
        outbound_enabled: false,
        max_call_duration: null,
      },
    });
    expect(wrapper.emitted('created')).toEqual([[created]]);
  });
});
