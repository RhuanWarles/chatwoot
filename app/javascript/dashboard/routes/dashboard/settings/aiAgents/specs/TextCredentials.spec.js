import { shallowMount, flushPromises } from '@vue/test-utils';
import TextCredentials from '../TextCredentials.vue';
import SaasAI from 'dashboard/api/saasAI';

vi.mock('vue-i18n', async importOriginal => ({
  ...(await importOriginal()),
  useI18n: () => ({
    t: key => key,
    tm: () => ({ generic: 'error' }),
    rt: value => value,
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/saasAI', () => ({
  default: { get: vi.fn(), save: vi.fn() },
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

beforeEach(() => {
  vi.clearAllMocks();
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
