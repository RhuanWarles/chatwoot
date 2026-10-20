import { defineComponent, ref } from 'vue';
import { shallowMount, flushPromises } from '@vue/test-utils';
import Index from './Index.vue';
import ConnectionDetails from './ConnectionDetails.vue';
import WhatsappConnectionsAPI from 'dashboard/api/whatsappConnections';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const mocks = vi.hoisted(() => ({
  push: vi.fn(),
  open: vi.fn(),
  close: vi.fn(),
}));
let accountId;
let route;
vi.mock('vue-router', () => ({ useRouter: () => ({ push: mocks.push }) }));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountId,
    route,
    accountScopedRoute: (name, params) => ({
      name,
      params: { accountId: accountId.value, ...params },
    }),
  }),
}));
vi.mock('dashboard/api/whatsappConnections', () => ({
  default: {
    get: vi.fn(),
    show: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    connect: vi.fn(),
    disconnect: vi.fn(),
  },
}));

const dialogStub = defineComponent({
  setup(_, { expose }) {
    expose({ open: mocks.open, close: mocks.close });
  },
  template: '<div><slot /></div>',
});

describe('WhatsApp management screens', () => {
  beforeEach(() => {
    accountId = ref(1);
    route = { params: {} };
    WhatsappConnectionsAPI.get.mockResolvedValue({
      data: { connections: [], inboxes: [{ id: 9, name: 'Support' }] },
    });
    WhatsappConnectionsAPI.show.mockResolvedValue({
      data: {
        id: 36,
        display_name: 'Rhuan',
        inbox_id: 9,
        status: 'connected',
        phone_number: '5562999999999',
      },
    });
  });

  it('renders the empty state and creates using only the display name and inbox ID', async () => {
    WhatsappConnectionsAPI.create.mockResolvedValue({ data: { id: 36 } });
    const wrapper = shallowMount(Index, {
      global: { stubs: { Dialog: dialogStub } },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('WHATSAPP_CONNECTIONS.EMPTY_TITLE');
    wrapper.findComponent(Input).vm.$emit('update:modelValue', ' Commercial ');
    wrapper.findComponent(Select).vm.$emit('update:modelValue', 9);
    await wrapper.findComponent(Dialog).vm.$emit('confirm');
    await flushPromises();
    expect(WhatsappConnectionsAPI.create).toHaveBeenCalledWith({
      display_name: 'Commercial',
      inbox_id: 9,
    });
    expect(mocks.push).toHaveBeenCalledWith({
      name: 'whatsapp_connection',
      params: { accountId: 1, connectionId: 36 },
    });
    wrapper.unmount();
  });

  it('lists connection cards and preserves backend-scoped inbox choices', async () => {
    WhatsappConnectionsAPI.get.mockResolvedValue({
      data: {
        connections: [
          {
            id: 36,
            display_name: 'Rhuan',
            status: 'connected',
            inbox_id: 9,
            inbox: { id: 9, name: 'Support' },
          },
        ],
        inboxes: [
          { id: 9, name: 'Support' },
          { id: 10, name: 'Commercial' },
        ],
      },
    });
    const wrapper = shallowMount(Index, {
      global: { stubs: { Dialog: dialogStub } },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('Rhuan');
    expect(wrapper.findComponent(Select).props('options')).toContainEqual({
      value: 9,
      label: 'Support',
      disabled: true,
    });
    wrapper.unmount();
  });

  it('shows live number/status and unlinks through the Rails update API', async () => {
    WhatsappConnectionsAPI.update.mockResolvedValue({
      data: {
        id: 36,
        display_name: 'Renamed',
        inbox_id: null,
        status: 'connected',
      },
    });
    const wrapper = shallowMount(ConnectionDetails, {
      props: { connectionId: 36 },
      global: { stubs: { Dialog: dialogStub } },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('5562999999999');
    wrapper.findComponent(Input).vm.$emit('update:modelValue', 'Renamed');
    wrapper.findComponent(Select).vm.$emit('update:modelValue', '');
    const saveButton = wrapper
      .findAllComponents(Button)
      .find(button => button.props('label') === 'WHATSAPP_CONNECTIONS.SAVE');
    await saveButton.vm.$emit('click');
    await flushPromises();
    expect(WhatsappConnectionsAPI.update).toHaveBeenCalledWith(36, {
      display_name: 'Renamed',
      inbox_id: null,
    });
    wrapper.unmount();
  });

  it('requires the confirmation dialog before deleting a connection', async () => {
    WhatsappConnectionsAPI.delete.mockResolvedValue({ status: 204, data: '' });
    const wrapper = shallowMount(ConnectionDetails, {
      props: { connectionId: 36 },
      global: { stubs: { Dialog: dialogStub } },
    });
    await flushPromises();
    const deleteButton = wrapper
      .findAllComponents(Button)
      .find(button => button.props('label') === 'WHATSAPP_CONNECTIONS.DELETE');
    await deleteButton.vm.$emit('click');
    expect(mocks.open).toHaveBeenCalled();
    expect(WhatsappConnectionsAPI.delete).not.toHaveBeenCalled();
    wrapper.findComponent(Dialog).vm.$emit('confirm');
    await flushPromises();
    expect(WhatsappConnectionsAPI.delete).toHaveBeenCalledWith(36);
    expect(wrapper.emitted('deleted')).toHaveLength(1);
    wrapper.unmount();
  });

  it('disconnects without deleting or unlinking', async () => {
    WhatsappConnectionsAPI.disconnect.mockResolvedValue({
      data: {
        id: 36,
        display_name: 'Rhuan',
        inbox_id: 9,
        status: 'disconnected',
      },
    });
    const wrapper = shallowMount(ConnectionDetails, {
      props: { connectionId: 36 },
      global: { stubs: { Dialog: dialogStub } },
    });
    await flushPromises();
    const disconnectButton = wrapper
      .findAllComponents(Button)
      .find(
        button => button.props('label') === 'WHATSAPP_CONNECTIONS.DISCONNECT'
      );
    disconnectButton.vm.$emit('click');
    await flushPromises();
    expect(WhatsappConnectionsAPI.disconnect).toHaveBeenCalledWith(36);
    expect(WhatsappConnectionsAPI.delete).not.toHaveBeenCalled();
    expect(WhatsappConnectionsAPI.update).not.toHaveBeenCalled();
    wrapper.unmount();
  });
});
