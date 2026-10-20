import { ref } from 'vue';
import { shallowMount, flushPromises } from '@vue/test-utils';
import EvolutionConfiguration from '../EvolutionConfiguration.vue';
import WhatsappConnectionsAPI from 'dashboard/api/whatsappConnections';
import inboxesAPI from 'dashboard/api/inboxes';
import Select from 'dashboard/components-next/select/Select.vue';

const mocks = vi.hoisted(() => ({ dispatch: vi.fn(), push: vi.fn() }));
let available;

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: mocks.dispatch }),
  useMapGetter: () => available,
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountScopedRoute: name => ({ name }) }),
}));
vi.mock('vue-router', () => ({ useRouter: () => ({ push: mocks.push }) }));
vi.mock('dashboard/api/whatsappConnections', () => ({
  default: { get: vi.fn(), update: vi.fn() },
}));
vi.mock('dashboard/api/inboxes', () => ({
  default: {
    getEvolutionConfiguration: vi.fn(),
    updateEvolutionConfiguration: vi.fn(),
  },
}));

describe('optional WhatsApp inbox configuration', () => {
  beforeEach(() => {
    available = ref(false);
    WhatsappConnectionsAPI.get.mockResolvedValue({ data: { connections: [] } });
    inboxesAPI.getEvolutionConfiguration.mockResolvedValue({
      data: { sign_msg: false },
    });
  });

  it('renders no integration controls and makes no calls when unavailable, even with legacy configuration', async () => {
    const wrapper = shallowMount(EvolutionConfiguration, {
      props: {
        inbox: {
          id: 1,
          additional_attributes: { evolution_instance_name: 'legacy-rhuan' },
        },
      },
    });
    await flushPromises();
    expect(wrapper.findComponent(Select).exists()).toBe(false);
    expect(WhatsappConnectionsAPI.get).not.toHaveBeenCalled();
    expect(inboxesAPI.getEvolutionConfiguration).not.toHaveBeenCalled();
    expect(mocks.dispatch).not.toHaveBeenCalled();
    wrapper.unmount();
  });

  it('preserves an unmatched manual value without silently updating the inbox', async () => {
    available.value = true;
    const wrapper = shallowMount(EvolutionConfiguration, {
      props: {
        inbox: {
          id: 1,
          additional_attributes: { evolution_instance_name: 'legacy-rhuan' },
        },
      },
      global: {
        stubs: {
          SettingsAccordion: { template: '<div><slot /></div>' },
          SettingsFieldSection: { template: '<div><slot /></div>' },
        },
      },
    });
    await flushPromises();
    expect(wrapper.findComponent(Select).props('modelValue')).toBe('legacy');
    expect(wrapper.findComponent(Select).props('options')).toContainEqual({
      value: 'legacy',
      label: 'WHATSAPP_CONNECTIONS.LEGACY_CONNECTION',
    });
    expect(WhatsappConnectionsAPI.update).not.toHaveBeenCalled();
    expect(mocks.dispatch).not.toHaveBeenCalled();
    wrapper.unmount();
  });

  it('lists only selectable connections from the account-scoped API and shows the current managed connection', async () => {
    available.value = true;
    WhatsappConnectionsAPI.get.mockResolvedValue({
      data: {
        connections: [
          {
            id: 5,
            display_name: 'Current',
            instance_name: 'account-1-managed',
            inbox_id: 1,
            status: 'connected',
          },
          {
            id: 6,
            display_name: 'Available',
            instance_name: 'account-1-free',
            inbox_id: null,
            status: 'disconnected',
          },
          {
            id: 7,
            display_name: 'Another inbox',
            instance_name: 'account-1-busy',
            inbox_id: 2,
            status: 'connected',
          },
        ],
      },
    });
    const wrapper = shallowMount(EvolutionConfiguration, {
      props: {
        inbox: {
          id: 1,
          additional_attributes: {
            evolution_instance_name: 'account-1-managed',
          },
        },
      },
      global: {
        stubs: {
          SettingsAccordion: { template: '<div><slot /></div>' },
          SettingsFieldSection: { template: '<div><slot /></div>' },
        },
      },
    });
    await flushPromises();
    expect(wrapper.findComponent(Select).props('modelValue')).toBe(5);
    expect(
      wrapper
        .findComponent(Select)
        .props('options')
        .map(option => option.value)
    ).toEqual([5, 6]);
    expect(WhatsappConnectionsAPI.update).not.toHaveBeenCalled();
    wrapper.unmount();
  });
});
