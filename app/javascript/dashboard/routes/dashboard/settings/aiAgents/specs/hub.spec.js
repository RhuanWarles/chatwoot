import { computed, reactive } from 'vue';
import { shallowMount, flushPromises } from '@vue/test-utils';
import Index from '../Index.vue';
import TextCredentials from '../TextCredentials.vue';
import VoiceAgents from '../VoiceAgents.vue';
import SaasAI from 'dashboard/api/saasAI';
import voiceAgentsAPI from 'dashboard/api/voiceAgents';

const mocks = vi.hoisted(() => ({
  replace: vi.fn(),
  route: null,
  accounts: null,
  alert: vi.fn(),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountId: computed(() => mocks.route.params.accountId),
    currentAccount: computed(
      () => mocks.accounts[mocks.route.params.accountId]
    ),
  }),
}));
vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
  useRouter: () => ({ replace: mocks.replace }),
}));
vi.mock('vue-i18n', async importOriginal => ({
  ...(await importOriginal()),
  useI18n: () => ({
    t: key => key,
    tm: () => ({ generic: 'error' }),
    rt: value => value,
  }),
}));
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => mocks.alert(...args),
}));
vi.mock('dashboard/api/saasAI', () => ({
  default: { get: vi.fn(), save: vi.fn() },
}));
vi.mock('dashboard/api/voiceAgents', () => ({
  default: { get: vi.fn(), create: vi.fn(), update: vi.fn(), delete: vi.fn() },
}));
vi.mock('../TextAgents.vue', () => ({
  default: { name: 'TextAgents', template: '<div />' },
}));
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: {
    name: 'Button',
    props: ['label', 'disabled'],
    template: '<button />',
  },
}));
vi.mock('dashboard/components-next/input/Input.vue', () => ({
  default: {
    name: 'Input',
    props: ['modelValue', 'label'],
    template: '<input />',
  },
}));
vi.mock('dashboard/components-next/combobox/ComboBox.vue', () => ({
  default: { name: 'ComboBox', template: '<div />' },
}));
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: { name: 'Dialog', template: '<div />' },
}));
vi.mock('dashboard/components-next/tabbar/TabBar.vue', () => ({
  default: {
    name: 'TabBar',
    props: ['tabs', 'initialActiveTab'],
    template: '<div />',
  },
}));

beforeEach(() => {
  vi.clearAllMocks();
  mocks.route = reactive({ params: { accountId: '1' }, query: {} });
  mocks.accounts = reactive({
    1: { features: { text_ai: true, voice_ai: true } },
  });
  SaasAI.get.mockResolvedValue({
    data: {
      settings: {
        text_mode: 'byok',
        text_provider: 'openai',
        text_model: 'gpt-4o-mini',
        encryption_ready: true,
        api_key_configured: true,
        inbound_enabled: true,
        outbound_enabled: true,
      },
    },
  });
  SaasAI.save.mockResolvedValue({ data: {} });
  voiceAgentsAPI.get.mockResolvedValue({
    data: { agents: [], providers: ['vapi'], duration_range: [10, 3600] },
  });
});

it('uses the URL tab on entry and refresh, defaults existing links to text and preserves other query parameters', async () => {
  const wrapper = shallowMount(Index, {
    global: { stubs: { RouterLink: true } },
  });
  expect(wrapper.findComponent({ name: 'TextAgents' }).exists()).toBe(true);
  wrapper
    .findComponent({ name: 'TabBar' })
    .vm.$emit('tabChanged', { value: 'voice' });
  expect(mocks.replace).toHaveBeenCalledWith({ query: { type: 'voice' } });
  mocks.route.query = { type: 'voice', other: 'keep' };
  await wrapper.vm.$nextTick();
  expect(wrapper.findComponent(VoiceAgents).exists()).toBe(true);
  wrapper
    .findComponent({ name: 'TabBar' })
    .vm.$emit('tabChanged', { value: 'text' });
  expect(mocks.replace).toHaveBeenLastCalledWith({
    query: { type: 'text', other: 'keep' },
  });
  wrapper.unmount();
  const refreshed = shallowMount(Index, {
    global: { stubs: { RouterLink: true } },
  });
  expect(refreshed.findComponent(VoiceAgents).exists()).toBe(true);
  refreshed.unmount();
});

it.each([
  [true, true, 'voice', ['text', 'voice'], 'VoiceAgents'],
  [true, false, 'voice', ['text'], 'TextAgents'],
  [false, true, 'text', ['voice'], 'VoiceAgents'],
  [false, false, 'voice', [], null],
])(
  'enforces text=%s voice=%s for direct URL type=%s before rendering a restricted tab',
  async (text, voice, requested, allowed, component) => {
    mocks.accounts[1].features = { text_ai: text, voice_ai: voice };
    mocks.route.query = { type: requested };
    const wrapper = shallowMount(Index, {
      global: { stubs: { RouterLink: true } },
    });
    const tabBar = wrapper.findComponent({ name: 'TabBar' });
    if (allowed.length) {
      expect(tabBar.props('tabs').map(tab => tab.value)).toEqual(allowed);
      expect(wrapper.findComponent({ name: component }).exists()).toBe(true);
      const forbidden =
        component === 'TextAgents' ? 'VoiceAgents' : 'TextAgents';
      if (allowed.length === 1)
        expect(wrapper.findComponent({ name: forbidden }).exists()).toBe(false);
      if (!allowed.includes(requested)) {
        expect(mocks.replace).toHaveBeenCalledWith({
          query: { type: allowed[0] },
        });
      }
    } else {
      expect(tabBar.exists()).toBe(false);
      expect(wrapper.findComponent({ name: 'TextAgents' }).exists()).toBe(
        false
      );
      expect(wrapper.findComponent({ name: 'VoiceAgents' }).exists()).toBe(
        false
      );
      expect(wrapper.text()).toContain('AI_HUB.UNAVAILABLE');
    }
    wrapper.unmount();
  }
);

it('recalculates tabs and access when switching accounts without logout', async () => {
  mocks.accounts[2] = { features: { text_ai: true } };
  mocks.route.query = { type: 'voice' };
  const wrapper = shallowMount(Index, {
    global: { stubs: { RouterLink: true } },
  });
  expect(wrapper.findComponent(VoiceAgents).exists()).toBe(true);
  mocks.route.params.accountId = '2';
  await wrapper.vm.$nextTick();
  expect(wrapper.findComponent(VoiceAgents).exists()).toBe(false);
  expect(wrapper.findComponent({ name: 'TextAgents' }).exists()).toBe(true);
  expect(mocks.replace).toHaveBeenLastCalledWith({ query: { type: 'text' } });
  wrapper.unmount();
});

it('saves text settings through the existing API without overwriting voice settings or removing the stored key', async () => {
  const wrapper = shallowMount(TextCredentials);
  await flushPromises();
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(SaasAI.save).toHaveBeenCalledWith({
    text_mode: 'byok',
    text_provider: 'openai',
    text_model: 'gpt-4o-mini',
  });
  expect(SaasAI.save.mock.calls[0][0]).not.toHaveProperty('text_api_key');
  expect(SaasAI.save.mock.calls[0][0]).not.toHaveProperty('inbound_enabled');
  wrapper.unmount();
});

it('keeps a failed voice draft open for retry and submits only voice configuration', async () => {
  const open = vi.fn();
  const close = vi.fn();
  const wrapper = shallowMount(VoiceAgents, {
    global: {
      stubs: {
        Dialog: {
          name: 'Dialog',
          props: ['title'],
          methods: { open, close },
          template: '<div><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  wrapper.findAllComponents({ name: 'Button' })[0].vm.$emit('click');
  await wrapper.vm.$nextTick();
  const nameInput = wrapper.findAllComponents({ name: 'Input' })[0];
  nameInput.vm.$emit('update:modelValue', 'Fernanda');
  await wrapper.vm.$nextTick();
  voiceAgentsAPI.create.mockRejectedValueOnce(new Error('network'));
  const dialog = wrapper.findAllComponents({ name: 'Dialog' })[0];
  dialog.vm.$emit('confirm');
  await flushPromises();
  expect(close).not.toHaveBeenCalled();
  expect(wrapper.text()).toContain('AI_AGENTS.SAVE_ERROR');
  expect(nameInput.props('modelValue')).toBe('Fernanda');
  voiceAgentsAPI.create.mockResolvedValueOnce({
    data: { id: 1, name: 'Fernanda', provider: 'vapi', active: false },
  });
  dialog.vm.$emit('confirm');
  await flushPromises();
  expect(voiceAgentsAPI.create).toHaveBeenLastCalledWith({
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
  expect(close).toHaveBeenCalledOnce();
  expect(wrapper.text()).toContain('Fernanda');
  wrapper.unmount();
});
